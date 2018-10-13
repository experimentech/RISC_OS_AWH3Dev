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
/* tracing.c - output debug similar to full blown DebugLib */

/* Low-level debugging output routine */
extern int asm_writech(char c); /* provided in assembler - handles newline */
                                /* Returns < 0 if trace output is being ignored right now. */

/* Output to output stream */
static void writech(char **dest, char c)
{
  if (dest == 0 || *dest == 0) asm_writech(c); else {*(*dest)++ = c; **dest = 0;}
}
#ifdef TESTDEBUG
static void writes(char **d, char *c) {while(*c != 0) writech(d, *c++);}
#endif
static void writehex(char **d, int i, int width)
{
  int j;
  for (j = 4*(width-1); j >= 0; j-=4) writech(d, "0123456789abcdef"[(i>>j)&15]);
}
static void cwritech(char **d, int *column, char c) {writech(d, c); *column = c == '\n' ? 0 : *column+1;}
static void cwrites(char **d, int *column, char *c) {if (c != 0) {while (*c != 0) cwritech(d, column, *c++);}}
static void cwritehex(char **d, int *column, int i, int width) {*column += width; writehex(d, i, width);}

static void do_vprintf(char *d, const char *format, va_list args)
{
  /* Only %% for %, %s for string, %c for character,
   * %i for integer, %x for hex, %t<column> for tab implemented
   */
  int ch;
  int column = 0;

  asm_writech(4);
  while ((ch = *format++) != 0)
  {
    if (ch == '%')
    {
      int width = 8; /* default width for hex output */

      while (*format == '0') format++;
      if (*format >= '1' && *format <= '9') width = *format-'0'; /* probably only one digit! */
      while (*format >= '0' && *format <= '9') format++; /* read over width specifier - better than gagging! */

      switch (*format++)
      {
      case '%': cwritech(&d, &column, '%'); break;
      case 's': cwrites(&d, &column, va_arg(args, char*)); break;
      case 'c': cwritech(&d, &column, va_arg(args, int)); break;
      case 'd':
      case 'i':
                {
                  int i = va_arg(args, int);
                  int j = 16;
                  BOOL neg = FALSE;
                  char c[16];
                  int ten = 10;

                  if (i < 0) {neg = TRUE; i = -i;}
                  if (i < 0)
                    cwrites(&d, &column, "0x80000000"); /* minint - probably more useful in hex! */
                  else
                  {
                    c[--j] = 0;
                    while (i >= 10)
                    {
                      c[--j] = '0' + (i % ten);
                      i = i / ten;
                    }
                    c[--j] = '0' + i;
                    if (neg) c[--j] = '-';
                    cwrites(&d, &column, &c[j]);
                  }
                }
                break;
      case 'x': cwritehex(&d, &column, va_arg(args, int), width);
                break;
      case 't': /* tab to specific column */
                {
                  int n = 0;
                  while (*format >= '0' && *format <= '9') n = n * 10 + (*format++ - '0');
                  while (column < n) cwritech(&d, &column, ' ');
                }
                break;
      }
      if (*format == '.') format++; /* terminator for esc sequence. */
    }
    else
      cwritech(&d, &column, ch);
  }
  asm_writech(0xd);
}

/* As conventional printf & sprintf */
void do_printf(const char *unused, const char *format, ...)
{
  va_list args;
  va_start(args, format);
  do_vprintf(NULL, format, args);
  va_end(args);
  UNUSED(unused);
}

void do_sprintf(char *d, const char *format, ...)
{
  va_list args;
  va_start(args, format);
  do_vprintf(d, format, args);
  va_end(args);
}

/* As conventional strcat */
char *strcat(char *aa, const char *b)
{
  char *a = aa;

  while (*a != 0) a++; /* find end of string */
  while (*b != 0) *a++ = *b++;
  *a = 0;
  return aa;
}

/* The assert macro calls this with one that outputs into the trace */
void do_assert(const char *file, int line, BOOL arg, int error, const char *describe)
{
  if (arg == 0)
  {
    dprintf(("", "ASSERTION FAILED (%s line %i): %s\n", file, line, describe));
    exit_erl(error, line);
  }
}

/* Inject a comment into the output assembly */
void do_comment(const char *text)
{
  dprintf(("", "%t20; %s\n", text));
}

/* Is it or isn't it */
static char *whether(BOOL p)
{
  return p ? "YES" : "NO";
}
