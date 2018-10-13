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
#pragma force_top_level
#pragma include_only_once

/* time.h: ISO 'C' (9899:1999) library header, section 7.23 */
/* Copyright (C) Codemist Ltd. */
/* Copyright (C) Acorn Computers Ltd. 1992 */
/* version 2.02 */

/*
 * time.h declares two macros, four types and several functions for
 * manipulating time. Many functions deal with a calendar time that represents
 * the current date (according to the Gregorian calendar) and time. Some
 * functions deal with local time, which is the caledar time expressed for some
 * specific time zone, and with Dalight Savings Time, which is a temporary
 * change in the algorithm for determining local time.
 */

#ifndef __time_h
#define __time_h

#ifndef __size_t
#define __size_t 1
typedef unsigned int size_t;   /* from <stddef.h> */
#endif

#ifndef NULL
#  define NULL 0
#endif

#ifdef __CLK_TCK
#  define CLK_TCK         __CLK_TCK    /* Pre-Dec 88 Draft; under threat */
#  define CLOCKS_PER_SEC  __CLK_TCK    /* Dec 1988 Draft                 */
#else
#  define CLK_TCK         100          /* for the BBC                    */
#  define CLOCKS_PER_SEC  100          /* for the BBC                    */
   /* the number per second of the value returned by the clock function. */
#endif

typedef unsigned int clock_t;    /* cpu time type - in centisecs on bbc  */
typedef unsigned int time_t;     /* date/time in unix secs past 1-Jan-70 */

struct tm {
  int tm_sec;   /* seconds after the minute, 0 to 60
                   (0 - 60 allows for the occasional leap second) */
  int tm_min;   /* minutes after the hour, 0 to 59 */
  int tm_hour;  /* hours since midnight, 0 to 23 */
  int tm_mday;  /* day of the month, 1 to 31 */
  int tm_mon;   /* months since January, 0 to 11 */
  int tm_year;  /* years since 1900 */
  int tm_wday;  /* days since Sunday, 0 to 6 */
  int tm_yday;  /* days since January 1, 0 to 365 */
  int tm_isdst; /* Daylight Savings Time flag */
};
   /* struct tm holds the components of a calendar time, called the broken-down
    * time. The value of tm_isdst is positive if Daylight Savings Time is in
    * effect, zero if Daylight Savings Time is not in effect, and negative if
    * the information is not available.
    */

#ifdef __cplusplus
#define restrict
extern "C" {
#else
#define restrict __restrict
#endif
clock_t clock(void);
   /* determines the processor time used.
    * Returns: the implementation's best approximation to the processor time
    *          used by the program since program invocation. The time in
    *          seconds is the value returned divided by the value of the macro
    *          CLK_TCK. The value (clock_t)-1 is returned if the processor time
    *          used is not available.
    */
double difftime(time_t /*time1*/, time_t /*time0*/);
   /*
    * computes the difference between two calendar times: time1 - time0.
    * Returns: the difference expressed in seconds as a double.
    */
time_t mktime(struct tm * /*timeptr*/);
   /*
    * converts the broken-down time, expressed as local time, in the structure
    * pointed to by timeptr into a calendar time value with the same encoding
    * as that of the values returned by the time function. The original values
    * of the tm_wday and tm_yday components of the structure are ignored, and
    * the original values of the other components are not restricted to the
    * ranges indicated above. On successful completion, the values of the
    * tm_wday and tm_yday structure components are set appropriately, and the
    * other components are set to represent the specified calendar time, but
    * with their values forced to the ranges indicated above; the final value
    * of tm_mday is not set until tm_mon and tm_year are determined.
    * Returns: the specified calendar time encoded as a value of type time_t.
    *          If the calendar time cannot be represented, the function returns
    *          the value (time_t)-1.
    */
time_t time(time_t * /*timer*/);
   /*
    * determines the current calendar time. The encoding of the value is
    * unspecified.
    * Returns: the implementations best approximation to the current calendar
    *          time. The value (time_t)-1 is returned if the calendar time is
    *          not available. If timer is not a null pointer, the return value
    *          is also assigned to the object it points to.
    */

char *asctime(const struct tm * /*timeptr*/);
   /*
    * converts the broken-down time in the structure pointed to by timeptr into
    * a string in the form Sun Sep 16 01:03:52 1973\n\0.
    * Returns: a pointer to the string containing the date and time.
    */
char *ctime(const time_t * /*timer*/);
   /*
    * converts the calendar time pointed to by timer to local time in the form
    * of a string. It is equivalent to asctime(localtime(timer));
    * Returns: the pointer returned by the asctime function with that
    *          broken-down time as argument.
    */
struct tm *gmtime(const time_t * /*timer*/);
   /*
    * converts the calendar time pointed to by timer into a broken-down time,
    * expressed as Greenwich Mean Time (GMT).
    * Returns: a pointer to that object or a null pointer if GMT not available.
    */
struct tm *localtime(const time_t * /*timer*/);
   /*
    * converts the calendar time pointed to by timer into a broken-down time,
    * expressed a local time.
    * Returns: a pointer to that object.
    */
size_t strftime(char * restrict /*s*/, size_t /*maxsize*/,
                const char * restrict /*format*/,
                const struct tm * restrict /*timeptr*/);
   /*
    * places characters into the array pointed to by s as controlled by the
    * string pointed to by format. The format string consists of zero or more
    * directives and ordinary characters. A directive consists of a % character
    * followed by a character that determines the directive's behaviour. All
    * ordinary characters (including the terminating null character) are copied
    * unchanged into the array. No more than maxsize characters are placed into
    * the array. Each directive is replaced by appropriate characters  as
    * described in the following list. The appropriate characters are
    * determined by the LC_TIME category of the current locale and by the
    * values contained in the structure pointed to by timeptr.
    * %a is replaced by the locale's abbreviated weekday name.
    * %A is replaced by the locale's full weekday name.
    * %b is replaced by the locale's abbreviated month name.
    * %B is replaced by the locale's full month name.
    * %c is replaced by the locale's appropriate date and time representation.
    * %C is replaced by the century as a decimal number (00-99).
    * %d is replaced by the day of the month as a decimal number (01-31).
    * %D is equivalent to "%m/%d/%y".
    * %e is replaced by the day of the month as a decimal number (1-31); a
    *       single digit is preceded by a space.
    * %F is equivalent to "%Y-%m-%d" (the ISO 8601 date format).
    * %g is replaced by the last 2 digits of the ISO 8601 week-based year
    *       (00-99).
    * %G is replaced by the ISO 8601 week-based year as a decimal number
    *       (eg 1997).
    * %h is equivalent to "%b".
    * %H is replaced by the hour (24-hour clock) as a decimal number (00-23).
    * %I is replaced by the hour (12-hour clock) as a decimal number (01-12).
    * %j is replaced by the day of the year as a decimal number (001-366).
    * %m is replaced by the month as a decimal number (01-12).
    * %M is replaced by the minute as a decimal number (00-59).
    * %n is replaced by a new-line character.
    * %p is replaced by the locale's equivalent of either AM or PM designations
    *       associated with a 12-hour clock.
    * %r is replaced by the locale's 12-hour clock time.
    * %R is equivalent to "%H:%M".
    * %S is replaced by the second as a decimal number (00-61).
    * %t is replaced by a horizontal-tab character.
    * %T is equivalent to "%H:%M:%S" (the ISO 8601 time format).
    * %u is replaced by the ISO 8601 weekday as a decimal number (1-7), where
    *       Monday is 1.
    * %U is replaced by the week number of the year (Sunday as the first day of
    *       week 1) as a decimal number (00-53).
    * %V is replaced by the ISO 8601 week number as a decimal number (01-53).
    * %w is replaced by the weekday as a decimal number (0(Sunday) - 6).
    * %W is replaced by the week number of the year (Monday as the first day of
    *       week 1) as a decimal number (00-53).
    * %x is replaced by the locale's appropriate date representation.
    * %X is replaced by the locale's appropriate time representation.
    * %y is replaced by the year without century as a decimal number (00-99).
    * %Y is replaced by the year with century as a decimal number.
    * %z is replaced by the offset from UTC in the ISO 8601 format ("-0430"),
            or by no characters if no time zone is determinable.
    * %Z is replaced by the timezone name or abbreviation, or by no characters
    *       if no time zone is determinable.
    * %% is replaced by %.
    * If a directive is not one of the above, the behaviour is undefined.
    * Returns: If the total number of resulting characters including the
    *          terminating null character is not more than maxsize, the
    *          strftime function returns the number of characters placed into
    *          the array pointed to by s not including the terminating null
    *          character. otherwise, zero is returned and the contents of the
    *          array are indeterminate.
    */
#ifdef __cplusplus
}
#endif
#undef restrict

#endif

/* end of time.h */
