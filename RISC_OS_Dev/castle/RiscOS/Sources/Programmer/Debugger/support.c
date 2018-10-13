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
#include "dis2.h"

/* Minimal sprintf() implementation and other support functions */

size_t strlen(const char *c)
{
	size_t count=0;
	while(*c++)
		count++;
	return count;
}

char *strcat(char *str1,const char *str2)
{
	char *ret = str1;
	while(*str1)
		str1++;
	while((*str1++ = *str2++) != 0) {};
	return ret;
}

int strcmp(const char *str1, const char *str2)
{
	char c;
	int diff;
	do
	{
		c = *str1++;
		diff = c - *str2++;
	} while (c && !diff);
	return diff;
}

void *memcpy(void *ptr1,const void *ptr2,size_t n)
{
	while(n--)
	{
		((char *) ptr1)[n] = ((char *) ptr2)[n];
	}
	return ptr1;
}

int sprintf(char *out,const char *format,...)
{
	va_list a;
	va_start(a,format);
	int ret = vsnprintf(out,SIZE_MAX,format,a);
	va_end(a);
	return ret;
}

extern int _sprintf(char *out,const char *format,...);

int _sprintf(char *out,const char *format,...)
{
	va_list a;
	va_start(a,format);
	int ret = vsnprintf(out,SIZE_MAX,format,a);
	va_end(a);
	return ret;
}

int snprintf(char *out,size_t max,const char *format,...)
{
	va_list a;
	va_start(a,format);
	int ret = vsnprintf(out,max,format,a);
	va_end(a);
	return ret;
}

extern int _snprintf(char *out,size_t max,const char *format,...);

int _snprintf(char *out,size_t max,const char *format,...)
{
	va_list a;
	va_start(a,format);
	int ret = vsnprintf(out,max,format,a);
	va_end(a);
	return ret;
}

int vsprintf(char *out,const char *format,va_list a)
{
	return vsnprintf(out,SIZE_MAX,format,a);
}

#define OUTC(C) do { char chr = C; if (count < usable_max) out[count] = chr; count++; } while(0)

int vsnprintf(char *out,size_t max,const char *format,va_list a)
{
	size_t count=0;
	int c;
	size_t usable_max = (out ? max : 0);
	while((c = *format++) != 0)
	{
		if(c == '%')
		{
			/* We'll only deal with the following format specifiers:
			   %[-<width>]s   (control-terminated - to cope with messages)
			   %c
			   %<width>[ll]X
			   %<width>[ll]x
			   %d
			   %u
			*/
			int width=0;
			bool islong=false;
			c = *format++;
			if (c == '-')
				c = *format++;
			while((c >= '0') && (c <= '9'))
			{
				width = width*10 + c - '0';
				c = *format++;
			}
			switch(c)
			{
			case 's':
				{
				const char *s = va_arg(a,const char *);
				if(width)
				{
					/* Assume left-justified */
					do
					{
						OUTC(((*s >= ' ') ? *s++ : ' '));
					}
					while(--width);
				}
				else
				{
					while(*s >= ' ')
					{
						OUTC(*s++);
						width--;
					}
				}
				}
				break;
			case 'c':
				OUTC(va_arg(a,int));
				break;
			case 'l':
				islong = true;
				format++;
				c = *format++;
				/* Fall through... */
			case 'X':
			case 'x':
				{
				uint64_t h;
				if(islong)
					h = va_arg(a,uint64_t);
				else
					h = va_arg(a,unsigned int);
				int i = 15;
				if(!width)
					width = 1;
				do
				{
					unsigned int n = (unsigned int) (h>>60);
					if(n || (i<width))
					{
						width = 16;
						char c2;
						if(n <= 9)
							c2 = n+'0';
						else if(c == 'X')
							c2 = n+'A'-10;
						else
							c2 = n+'a'-10;
						OUTC(c2);
					}
					h=h<<4;
				} while(--i >= 0);
				}
				break;
			case 'd':
			case 'u':
				{
				unsigned int i = va_arg(a,unsigned int);
				if((i & 0x80000000) && (c == 'd'))
				{
					i = -i;
					OUTC('-');
				}
				while(i)
				{
					unsigned int j=1;
					int k=0;
					while((j < 0x10000000) && (j*10 <= i))
					{
						j *= 10;
						k++;
					}
					while(width > k)
					{
						OUTC('0');
						width--;
					}
					c = '0';
					while(i >= j)
					{
						i -= j;
						c++;
					}
					OUTC(c);
					width = k-1;
				}
				while(width-- >= 0)
					OUTC('0');
				}
				break;
			}
		}
		else
		{
			OUTC(c);
		}
	}
	if (out && max)
	{
		out[(count < max) ? count : (max-1)] = 0;
	}
	return count;
}

/* Main function called by assembler code */
static const char *conds_cscc[16] = {"EQ","NE","CS","CC","MI","PL","VS","VC","HI","LS","GE","LT","GT","LE","","NV"};

extern char *arm_engine_fromasm(char *buffer,uint32_t instr,uint32_t addr,char **regnames,size_t bufsize);

char *arm_engine_fromasm(char *buffer,uint32_t instr,uint32_t addr,char **regnames,size_t bufsize)
{
	dis_options options;
	for(int i=0;i<16;i++)
		options.regs[i] = regnames[i];
	options.cond = conds_cscc;
	options.reggroups = 0xffff;
	options.warnversions = ~0 - (1<<FPA);
	options.ual = false;
	options.vfpual = true;
	options.dci = false;
	options.bashex = true;
	options.nonstandard_undefined = true;
	options.allhex = false;
	options.swihash = false;
	options.positionind = false;
	options.cols[0] = 8;
	options.cols[1] = 27;
	options.swimode = SWIMODE_NAME;
	options.lfmsfmmode = LFMSFM_FORM1;
	options.comment = ';';

	return arm_engine(instr,addr,&options,buffer,bufsize);
}
