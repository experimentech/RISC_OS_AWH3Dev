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
/* Code copied from shared C library is Copyright (C) Codemist Ltd., 1988 */
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <limits.h>

__global_reg(6) void *sb;

#undef putchar
#undef putc

#define NO_FLOATING_POINT

static inline int isdigit(int c)
{
    return c >= '0' && c <= '9';
}

size_t strlen(const char *s)
{
    size_t len = 0;
    while (*s++ != '\0')
        len++;
    return len;
}

char* strncpy (char* dest, const char* src, size_t n)
{
  memcpy (dest, src, n);
  return dest;
}

void *memcpy(void *dst, const void *src, size_t len)
{
    char *d = dst;
    const char *s = src;
    while (len--)
        *d++ = *s++;
    return dst;
}

#define intofdigit(x) ((x)-'0')

int putchar(int c)
{
    extern void HAL_DebugTX(int);
    if (c == '\n') HAL_DebugTX('\r');
    HAL_DebugTX(c);
    return c;
}

int fputc(int c, FILE *stream)
{
    if (stream == NULL)
        return putchar(c);
    else if (stream->__flag & _IOSTRG)
    {
        /* s[n]printf */
        if (--stream->__ocnt >= 0)
            return *stream->__ptr++ = c;
        else
        {
            stream->__ocnt = 0;
            stream->__flag |= _IOERR;
            return EOF;
        }
    }
    else
    {
        stream->__flag |= _IOERR;
        return EOF;
    }
}

int putc(int c, FILE *stream)
{
    return fputc(c, stream);
}

#define _LJUSTIFY         01
#define _SIGNED           02
#define _BLANKER          04
#define _VARIANT         010
#define _PRECGIVEN       020
#define _LONGSPECIFIER   040
#define _SHORTSPEC      0100
#define _PADZERO        0200
#define _FPCONV         0400
#define _CHARSPEC      01000
#define _LONGLONGSPEC  02000

#define pr_padding(ch, n, p)  while(--n>=0) charcount++, putc(ch, p);

#define pre_padding(p)                                                    \
        if (!(flags&_LJUSTIFY))                                           \
        {   char padchar = flags & _PADZERO ? '0' : ' ';                  \
            pr_padding(padchar, width, p); }

#define post_padding(p)                                                   \
        if (flags&_LJUSTIFY)                                              \
        {   pr_padding(' ', width, p); }

static int printf_display(FILE *p, int flags, int ch, int precision, int width,
                   unsigned long long v, char *prefix,
                   char *hextab)
{
    int charcount = 0;
    int len = 0, before_dot = -1, after_dot = -1;
    char buff[32];       /* used to accumulate value to print    */
/* here at the end of the switch statement I gather together code that   */
/* is concerned with displaying integers.                                */
/* AM: maybe this would be better as a proc if we could get arg count down */
            if ((flags & _FPCONV+_PRECGIVEN)==0) precision = 1;
            switch (ch)
            {
    case 'p':
    case 'X':
    case 'x':   while(v!=0)
                {   buff[len++] = hextab[v & 0xf];
                    v = v >> 4;
                }
                break;
    case 'o':   while(v!=0)
                {   buff[len++] = '0' + (char)(v & 07);
                    v = v >> 3;
                }
                break;
    case 'u':
    case 'i':
    case 'd':   while (v != 0)
                {   unsigned long long vDiv10 = v / 10U;
                    buff[len++] = '0' + (char)(v - vDiv10 * 10U);
                    v = vDiv10;
                }
                break;

#ifndef NO_FLOATING_POINT
    case 'f':   case 'F':
    case 'g':   case 'G':
    case 'e':   case 'E':
    case 'a':   case 'A':
                len = fp_display_fn(ch, d, buff, flags,
/* The following arguments are set by fp_display_fn                      */
                                    &prefix, &precision,
                                    &before_dot, &after_dot);
                break;

#else
/* If floating point is not supported I display ALL %e, %f and %g        */
/* items as 0.0                                                          */
    default:    buff[0] = '0';
                buff[1] = '.';
                buff[2] = '0';
                len = 3;
                break;
#endif
            }
/* now work out how many leading '0's are needed for precision specifier */
/* _FPCONV is the case of FP printing in which case extra digits to make */
/* up the precision come within the number as marked by characters '<'   */
/* and '>' in the buffer.                                                */
            if (flags & _FPCONV)
            {   precision = 0;
                if (before_dot>0) precision = before_dot-1;
                if (after_dot>0) precision += after_dot-1;
            }
            else if ((precision -= len)<0) precision = 0;

/* and how much padding is needed */
            width -= (precision + len + strlen(prefix));

/* AM: ANSI appear (Oct 86) to suggest that the padding (even if with '0') */
/*     occurs before the possible sign!  Treat this as fatuous for now.    */
            if (!(flags & _PADZERO)) pre_padding(p);

            {   int c;                                      /* prefix    */
                while((c=*prefix++)!=0) { putc(c, p); charcount++; }
            }

            pre_padding(p);

/* floating point numbers are in buff[] the normal way around, while     */
/* integers have been pushed in with the digits in reverse order.        */
            if (flags & _FPCONV)
            {   int i, c;
                for (i = 0; i<len; i++)
                {   switch (c = buff[i])
                    {
            case '<':   pr_padding('0', before_dot, p);
                        break;
            case '>':   pr_padding('0', after_dot, p);
                        break;
            default:    putc(c, p);
                        charcount++;
                        break;
                    }
                }
            }
            else
            {   pr_padding('0', precision, p);
                charcount += len;
                while((len--)>0) putc(buff[len], p);
            }

/* By here if the padding has already been printed width will be zero    */
            post_padding(p);
            return charcount;
}

int vfprintf(FILE *p, const char *fmt, va_list args)
/* ACN: I apologize for this function - it seems long and ugly. Some of  */
/*      that is dealing with all the jolly flag options available with   */
/*      printf, and rather a lot more is a cautious floating point print */
/*      package that takes great care to avoid the corruption of its     */
/*      input by rounding, and to generate consistent decimal versions   */
/*      of all possible values in all possible formats.                  */
{
    int ch, charcount = 0;
    while ((ch = *fmt++) != 0)
    {   if (ch != '%') { putc(ch,p); charcount++; }
        else
        {   int flags = 0, width = 0, precision = 0;
/* The initialisation of hextab is spurious in that it will be set       */
/* to a real string before use, but necessary in that passing unset      */
/* parameters to functions is illegal in C.                              */
            char *prefix, *hextab = 0;
            unsigned long long v;
#ifndef NO_FLOATING_POINT
            double d;
#endif
/* This decodes all the nasty flags and options associated with an       */
/* entry in the format list. For some entries many of these options      */
/* will be useless, but I parse them all the same.                       */
            for (;;)
            {   switch (ch = *fmt++)
                {
/* '-'  Left justify converted flag. Only relevant if width specified    */
/* explicitly and converted value is too short to fill it.               */
        case '-':   flags = _LJUSTIFY | (flags & ~_PADZERO);
                    continue;

/* '+'  Always print either '+' or '-' at start of numbers.              */
        case '+':   flags |= _SIGNED;
                    continue;

/* ' '  Print either ' ' or '-' at start of numbers.                     */
        case ' ':   flags |= _BLANKER;
                    continue;

/* '#'  Variant on main print routine (effect varies across different    */
/*      styles, but for instance %#x puts 0x on the front of displayed   */
/*      numbers.                                                         */
        case '#':   flags |= _VARIANT;
                    continue;

/* '0'  Leading blanks are printed as zeros                              */
/*        This is a *** DEPRECATED FEATURE *** (precision subsumes)      */
        case '0':   flags |= _PADZERO;
                    continue;

        default:    break;
                }
                break;
            }

            /* now look for 'width' spec */
            {   int t = 0;
                if (ch=='*')
                {   t = va_arg(args, int);
/* If a negative width is passed as an argument I take its absolute      */
/* value and use the negativeness to indicate the presence of the '-'    */
/* flag (left justification). If '-' was already specified I lose it.    */
                    if (t<0)
                    {   t = - t;
                        flags ^= _LJUSTIFY;
                    }
                    ch = *fmt++;
                }
                else
                {   while (isdigit(ch))
                    {   t = t*10 + intofdigit(ch);
                        ch = *fmt++;
                    }
                }
                width = t>=0 ? t : 0;                 /* disallow -ve arg */
            }
            if (ch == '.')                            /* precision spec */
            {   int t = 0;
                ch = *fmt++;
                if (ch=='*')
                {   t = va_arg(args, int);
                    ch = *fmt++;
                }
                else while (isdigit(ch))
                {   t = t*10 + intofdigit(ch);
                    ch = *fmt++;
                }
                if (t >= 0) flags |= _PRECGIVEN, precision = t;
            }
            if (ch=='l' || ch=='L' || ch=='z' || ch=='t')
/* 'l'  Indicate that a numeric argument is 'long'. Here int and long    */
/*      are the same (32 bits) and so I can ignore this flag!            */
/* 'L'  Marks floating arguments as being of type long double. Here this */
/*      is the same as just double, and so I can ignore the flag.        */
/* 'z'  Indicates that a numeric argument is 'size_t', or that a %n      */
/*      argument is a pointer to a size_t. We can ignore it.             */
/* 't'  Indicates that a numeric argument is 'ptrdiff_t', or that a %n   */
/*      argument is a pointer to a ptrdiff_t. We can ignore it.          */
            {   int last = ch;
                flags |= _LONGSPECIFIER;
                ch = *fmt++;
/* 'll' Indicates that a numeric argument is 'long long', or that a %n   */
/*      argument is a pointer to long long int.                          */
                if (ch=='l' && last =='l')
                {   flags |= _LONGLONGSPEC;
                    ch = *fmt++;
                }
            }
            else if (ch=='h')
/* 'h'  Indicates that an integer value is to be treated as short.        */
            {   flags |= _SHORTSPEC;
                ch = *fmt++;
/* 'hh' Indicates that an integer value is to be treated as char.        */
                if (ch=='h')
                {   flags |= _CHARSPEC;
                    ch = *fmt++;
                }
            }
            else if (ch=='j')
/* 'j'  Indicates that a numeric argument is '[u]intmax_t', or than a %n */
/*      argument is a pointer to intmax_t.                               */
            {   flags |= _LONGSPECIFIER|_LONGLONGSPEC;
                ch = *fmt++;
            }

/* Now the options have been decoded - I can process the main dispatch   */
            switch (ch)
            {

/* %c causes a single character to be fetched from the argument list     */
/* and printed. This is subject to padding.                              */
    case 'c':   ch = va_arg(args, int);
                /* drop through */

/* %? where ? is some character not properly defined as a command char   */
/* for printf causes ? to be displayed with padding and field widths     */
/* as specified by the various modifers. %% is handled by this general   */
/* mechanism.                                                            */
    default:    width--;                        /* char width is 1       */
                pre_padding(p);
                putc(ch, p);
                charcount++;
                post_padding(p);
                continue;

/* If a '%' occurs at the end of a format string (possibly with a few    */
/* width specifiers and qualifiers after it) I end up here with a '\0'   */
/* in my hand. Unless I do something special the fact that the format    */
/* string terminated gets lost...                                        */
/* Ditto for '\n' terminated strings. "%\n" doesn't mean anything anyway */
    case '\n':
    case 0:     fmt--;
                continue;

/* %n assigns the number of chars printed so far to the next arg (which  */
/* is expected to be of type (int *), or (long long *) if 'j' or 'll'.   */
    case 'n':   if (flags & _LONGLONGSPEC)
                {   long long *xp = va_arg(args, long long *);
                    *xp = charcount;
                }
                else
                {   int *xp = va_arg(args, int *);
                    *xp = charcount;
                }
                continue;

/* %s prints a string. If a precision is given it can limit the number   */
/* of characters taken from the string, and padding and justification    */
/* behave as usual.                                                      */
    case 's':   {   char *str = va_arg(args, char *);
                    int i, n;
                    if (flags&_PRECGIVEN) {
                      n = 0;
                      while ((n < precision) && (str[n] != 0)) n++;
                    } else
                      n = strlen(str);
                    width -= n;
                    pre_padding(p);
                    for (i=0; i<n; i++) putc(str[i], p);
                    charcount += n;
                    post_padding(p);
                }
                continue;

/* %x prints in hexadecimal. %X does the same, but uses upper case       */
/* when printing things that are not (decimal) digits.                   */
/* I can share some messy decoding here with the code that deals with    */
/* octal and decimal output via %o and %d.                               */
    case 'X':   v = (flags & _LONGLONGSPEC) ? va_arg(args, unsigned long long)
                                            : va_arg(args, unsigned int);
                if (flags & _SHORTSPEC) v = (unsigned short)v;
                if (flags & _CHARSPEC) v = (unsigned char)v;
                hextab = "0123456789ABCDEF";
                prefix = ((flags&_VARIANT) != 0 && v != 0)? "0X" : "";
                if (flags & _PRECGIVEN) flags &= ~_PADZERO;
                break;

    case 'x':   v = (flags & _LONGLONGSPEC) ? va_arg(args, unsigned long long)
                                            : va_arg(args, unsigned int);
                if (flags & _SHORTSPEC) v = (unsigned short)v;
                if (flags & _CHARSPEC) v = (unsigned char)v;
                hextab = "0123456789abcdef";
                prefix = ((flags&_VARIANT) != 0 && v != 0)? "0x" : "";
                if (flags & _PRECGIVEN) flags &= ~_PADZERO;
                break;

/* %p is for printing a pointer - I print it as a hex number with the    */
/* precision always forced to 8.                                         */
    case 'p':   v = (unsigned int)va_arg(args, void *);
                hextab = "0123456789abcdef";
                prefix = (flags&_VARIANT) ? "@" : "";
                flags |= _PRECGIVEN;
                precision = 8;
                break;

    case 'o':   v = (flags & _LONGLONGSPEC) ? va_arg(args, unsigned long long)
                                            : va_arg(args, unsigned int);
                if (flags & _SHORTSPEC) v = (unsigned short)v;
                if (flags & _CHARSPEC) v = (unsigned char)v;
                prefix = (flags&_VARIANT) ? "0" : "";
                if (flags & _PRECGIVEN) flags &= ~_PADZERO;
                break;

    case 'u':   v = (flags & _LONGLONGSPEC) ? va_arg(args, unsigned long long)
                                            : va_arg(args, unsigned int);
                if (flags & _SHORTSPEC) v = (unsigned short)v;
                if (flags & _CHARSPEC) v = (unsigned char)v;
                prefix = "";
                if (flags & _PRECGIVEN) flags &= ~_PADZERO;
                break;

    case 'i':
    case 'd':   {   long long w;
                    w = (flags & _LONGLONGSPEC) ? va_arg(args, long long)
                                                : va_arg(args, int);
                    if (flags & _SHORTSPEC) w = (signed short)w;
                    if (flags & _CHARSPEC) w = (signed char)w;
                    if (w<0) v = 0ULL-w, prefix = "-";
                    else
                        v = w, prefix = (flags&_SIGNED) ? "+" :
                                        (flags&_BLANKER) ? " " : "";
                }
                if (flags & _PRECGIVEN) flags &= ~_PADZERO;
                break;

    case 'f':
    case 'F':
    case 'e':
    case 'E':
    case 'g':
    case 'G':
    case 'a':
    case 'A':   flags |= _FPCONV;
                if (!(flags & _PRECGIVEN)) precision = 6;
#ifndef NO_FLOATING_POINT
                d = va_arg(args, double);
                /* technically, for the call to printf_display() below to  */
                /* be legal and not reference an undefined variable we     */
                /* need to do the following (overwritten in fp_display_fn) */
                /* (It also stops dataflow analysis (-fa) complaining!)    */
                prefix = 0, hextab = 0, v = 0;
#else  /* NO_FLOATING_POINT */
                {   int w = va_arg(args, int);
                    w = va_arg(args, int);
/* If the pre-processor symbol FLOATING_POINT is not set I assume that   */
/* floating point is not available, and so support %e, %f, %g and %a     */
/* with a fragment of code that skips over the relevant argument.        */
/* I also assume that a double takes two int-sized arg positions.        */
                    prefix = (flags&_SIGNED) ? "+" :
                             (flags&_BLANKER) ? " " : "";
                }
#endif /* NO_FLOATING_POINT */
                break;

            }
            charcount += printf_display(p, flags, ch, precision, width, v,
                                        prefix, hextab);
            continue;
        }
    }
    return p && ferror(p) && !(p->__flag & _IOSTRG) ? EOF : charcount;
}

int vprintf(const char *format, va_list ap)
{
    return vfprintf(NULL, format, ap);
}

int printf(const char *format, ...)
{
    va_list ap;
    int n;

    va_start(ap, format);
    n = vprintf(format, ap);
    va_end(ap);

    return n;
}

int vsnprintf(char *output, size_t len, const char *format, va_list ap)
{
    FILE f;
    int n;

    f.__flag = _IOWRITE|_IOSTRG;
    f.__ocnt = len - 1;
    f.__ptr = f.__base = (unsigned char *) output;

    n = vfprintf(&f, format, ap);
    if (len > 0) *f.__ptr = '\0';

    return n;
}

int snprintf(char *output, size_t len, const char *format, ...)
{
    va_list ap;
    int n;

    va_start(ap, format);
    n = vsnprintf(output, len, format, ap);
    va_end(ap);

    return n;
}

int sprintf(char *output, const char *format, ...)
{
    va_list ap;
    int n;

    va_start(ap, format);
    n = vsnprintf(output, INT_MAX, format, ap);
    va_end(ap);

    return n;
}
int strcmp(const char *a, const char *b) /* lexical comparison on strings */
{
#ifdef _copywords
#ifdef BYTESEX_EVEN
/* Improved little-endian ARM strcmp code by Ian Rickards, ARM Ltd. */
/* sbrodie (06/04/01): unfortunately, it breaks strcmp() semantics required by the library definition */
    if ((((int)a | (int)b) & 3) == 0)
    {   int w1, w2, res, rc;
        nullbyte_prologue_();
        do {
            w1 = *(int *)a, a += 4;
            w2 = *(int *)b, b += 4;
            res = w1 - w2;
            if (res != 0) goto strcmp_checkbytes;

        } while (!word_has_nullbyte(w1));
        return 0;

strcmp_checkbytes:
#  ifdef WANT_ARMS_BROKEN_STRCMP_FOR_TOP_BIT_SET_CHARACTERS
/* carry propagation in subtract means that no subtract-per-byte is needed */
        rc = res << 24;
        if (rc != 0) return rc;
        if ((w1 & 0xff) == 0) return rc;

        rc = res << 16;
        if (rc != 0) return rc;
        if ((w1 & 0xff00) == 0) return rc;

        rc = res << 8;
        if (rc != 0) return rc;
        if ((w1 & 0xff0000) == 0) return rc;

        return res;
#  else  /* WANT_ARMS_BROKEN_STRCMP_FOR_TOP_BIT_SET_CHARACTERS */
        /* res is guaranteed non-zero, so rc will not be zero, therefore the loop
         * will find the bit eventually.  The shifting is done to ensure that if it
         * is the top-byte that contains the difference, we don't lose the sign bit
         * on the subtraction.  Right-shift on signed integers implementation defined,
         * but because we mask w1 and w2 with res, whether ASL or LSL is used is irrelevant.
         */
        rc = 0xFF;
        for (;;) {
          if (((w1 | w2) & rc) == 0) return 0;
          if (rc & res) return (w1 & rc) - (w2 & rc);
          w1 >>= 1;
          w2 >>= 1;
          res >>= 1;
          rc <<= 7;
        }
#  endif /* WANT_ARMS_BROKEN_STRCMP_FOR_TOP_BIT_SET_CHARACTERS */
#else
    if ((((int)a | (int)b) & 3) == 0)
    {   int w1, w2;
        nullbyte_prologue_();
        do {
            w1 = *(int *)a, a += 4;
            w2 = *(int *)b, b += 4;
        } while (w1 == w2 && !word_has_nullbyte(w1));

        /* sbrodie added note: it gets away with these implementation-defined right
         * shifts only because of the masking with 0xff.
         */
        for (;;)
        {   char c1 = (w1 >> 24) & 0xff, c2 = (w2 >> 24) & 0xff;
            int d = c1 - c2;
            if (d != 0) return d;
            if (c1 == 0) return 0;
            w1 = w1 << 8; w2 = w2 << 8;
        }
#endif
    }
#endif
    {   char const *ap = a; /* in order to move ap from reg a1 */
        for (;;)
        {   char c1 = *ap++, c2 = *b++;
            int d = c1 - c2;
            if (d != 0) return d;
            if (c1 == 0) return d;     /* no need to check c2 */
        }
    }
}

int strncmp(const char *a, const char * b, size_t n)
                                        /* as strcmp, but at most n chars */
{
#ifdef _copywords
    if ((((int)a | (int)b) & 3) == 0)
    {   int w;
        nullbyte_prologue_();
        while (n >= 4 && (w = *(int *)a) == *(int *)b && !word_has_nullbyte(w))
            a += 4, b += 4, n -= 4;
    }
#endif
    while (n-- > 0)
    {   char c1 = *a++, c2 = *b++;
        int d = c1 - c2;
        if (d != 0) return d;
        if (c1 == 0) return 0;     /* no need to check c2 */
    }
    return 0;
}


