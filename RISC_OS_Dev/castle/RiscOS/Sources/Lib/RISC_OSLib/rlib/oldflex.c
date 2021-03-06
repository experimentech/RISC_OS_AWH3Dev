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
/* Title  > c.flex
 * Purpose: provide memory allocation for interactive programs requiring
 *	    large chunks of store. Such programs must respond to memory
 *	    full errors, and must not suffer from fragmentation.
 * Version: 0.1
 */

/****************************************************************************
 * This source file was written by Acorn Computers Limited. It is part of   *
 * the "cwimp" library for writing applications in C for RISC OS. It may be *
 * used freely in the creation of programs for Archimedes. It should be     *
 * used with Acorn's C Compiler Release 2 or later.			    *
 *									    *
 * No support can be given to programmers using this code and, while we     *
 * believe that it is correct, no correspondence can be entered into	    *
 * concerning behaviour or bugs.					    *
 *									    *
 * Upgrades of this code may or may not appear, and while every effort will *
 * be made to keep such upgrades upwards compatible, no guarantees can be   *
 * given.								    *
 ***************************************************************************/

/*
 * Change list:
 *   18-Nov-88: If setting the slotsize fails, the original value is restored
 *   05-Dec-89: The concept of "budging" added. This allows the underlying C system to ask
 *     flex to move its base of memory up or down by an arbitrary amount. This
 *     allows malloc to grow and (if necessary) shrink.
 */

#define BOOL int
#define TRUE 1
#define FALSE 0

#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#include <kernel.h>

#include "os.h"
#include "werr.h"
#include "flex.h"
#include "trace.h"
#include "wimp.h"
#include "wimpt.h"
#include "msgs.h"

/* There are two alternative implementations in this file. */

static int flex__initialised = 0;

#if TRUE

/* This implementation goes above the original value of GetEnv,
to memory specifically requested from the Wimp (about which the
standard library, and malloc, know nothing). The heap is kept
totally compacted all the time, with pages being given back to
the Wimp whenever possible. */

typedef struct {
  flex_ptr anchor;	/* *anchor should point back to here. */
  int size;		/* in bytes. Exact size of logical area. */
			/* then the actual store follows. */
} flex__rec;

static void flex__fail(int i)
{
  werr(TRUE, msgs_lookup("flex1:Flex memory error"));
#if TRACE
  i = *(int *)-4 ;     /* go bang! */
#else
  i = i; /* avoid compiler warning. */
#endif
}

static void flex__check(void)
{
  if(flex__initialised == 0)
    werr(TRUE, msgs_lookup("flex3:Flex not initialised"));
}

static int roundup(int i) {
  return 0xfffffffc & (i + 3);
}

static char *flex__base;	/* lowest flex__rec - only for budging. */
static char *flex__freep;	/* free flex memory */
static char *flex__lim; 	/* limit of flex memory */
/* From base upwards, it's divided into store blocks of
  a flex__rec
  the space
  align up to next word.
*/

void flex__wimpslot(char **top) {
  /* read/write the top of available memory. *top == 0 -> just read. */
  int dud = -1;
  int slot = ((int) *top);
  if (slot != -1) slot -= 0x8000;
  tracef1("flex__wimpslot in: %i.\n", slot);
  wimpt_noerr(wimp_slotsize(&slot, &dud, &dud));
  *top = (char*) slot + 0x8000;
  tracef1("flex__wimpslot out: %i.\n", slot);
}

BOOL flex__more(int n)
{
  /* Tries to get at least n more bytes, raising flex__lim and
  returning TRUE if it can. */
  char *prev = flex__lim;

  flex__lim += n;
  flex__wimpslot(&flex__lim);
  tracef4("flex__more, freep=%i prevlim=%i n=%i lim=%i.\n",
    (int) flex__freep, (int) prev, n, (int) flex__lim);

  if (flex__lim < prev + n)
  {
   tracef0("flex__more FAILS.\n");
   flex__lim = prev;		 /* restore starting state:
				    extra memory is useless */
   flex__wimpslot(&flex__lim);
   return FALSE ;
  }
  else return TRUE ;
}

void flex__give(void) {
  /* Gives away memory, lowering flex__lim, if possible. */
#if TRACE
  int prev = (int) flex__lim;
#endif

  flex__lim = flex__freep;
  flex__wimpslot(&flex__lim);
  tracef3("flex__give, prev=%i freep=%i lim=%i.\n",
    prev, (int) flex__freep, (int) flex__lim);
}

BOOL flex__ensure(int n) {
  n -= flex__lim - flex__freep;
  tracef3("flex__ensure %i: %x %x.\n", n, (int) flex__lim, (int) flex__freep);
  if (n <= 0 || flex__more(n)) return TRUE; else return FALSE;
}

BOOL flex_alloc(flex_ptr anchor, int n)
{
  flex__rec *p;

  tracef2("flex_alloc %x %i.\n", (int) anchor, n);

  flex__check();

  if (n < 0 || ! flex__ensure(sizeof(flex__rec) + roundup(n))) {
    *anchor = 0;
    return FALSE;
  };

  p = (flex__rec*) flex__freep;
  flex__freep += sizeof(flex__rec) + roundup(n);

  p->anchor = anchor;
  p->size = n;
  *anchor = p + 1; /* sizeof(flex__rec), that is */
  return TRUE;
}

#if TRACE

static char *flex__start ;

/* show all flex pointers for debugging purposes */
void flex_display(void)
{
 flex__rec *p = (flex__rec *) flex__start ;

 tracef3("*****flex display: %x %x %x\n",
	  (int) flex__start, (int) flex__freep, (int) flex__lim) ;
 while (1)
 {
  if ((int) p >= (int) flex__freep) break;

  tracef("flex block @ %x->%x->%x",
	(int)p, (int)(p->anchor), (int)(*(p->anchor))) ;

  if (*(p->anchor) != p + 1) tracef("<<< bad block!");

  tracef("\n") ;
  p = (flex__rec*) (((char*) (p + 1)) + roundup(p->size));
 }
}

#endif

void flex__reanchor(flex__rec *p, int by) {
  /* Move all the anchors from p upwards. This is in anticipation
  of that block of the heap being shifted. */

  while (1) {
    if ((int) p >= (int) flex__freep) break;
   tracef1("flex__reanchor %x\n",(int) p) ;
    if (*(p->anchor) != p + 1) flex__fail(6);
    *(p->anchor) = ((char*) (p + 1)) + by;
    p = (flex__rec*) (((char*) (p + 1)) + roundup(p->size));
  };
}

void flex_free(flex_ptr anchor)
{
  flex__rec *p = ((flex__rec*) *anchor) - 1;
  int roundsize = roundup(p->size);
  flex__rec *next = (flex__rec*) (((char*) (p + 1)) + roundsize);

  tracef1("flex_free %i.\n", (int) anchor);
  flex__check();

  if (p->anchor != anchor) {
    flex__fail(0);
  };

  flex__reanchor(next, - (sizeof(flex__rec) + roundsize));

  memmove(
     p,
     next,
     flex__freep - (char*) next);

  flex__freep -= sizeof(flex__rec) + roundsize;

  flex__give();

  *anchor = 0;
}

int flex_size(flex_ptr anchor)
{
  flex__rec *p = ((flex__rec*) *anchor) - 1;
  flex__check();
  if (p->anchor != anchor) {
    flex__fail(4);
  }
  return(p->size);
}

int flex_extend(flex_ptr anchor, int newsize)
{
  flex__rec *p = ((flex__rec*) *anchor) - 1;
  flex__check();
  return(flex_midextend(anchor, p->size, newsize - p->size));
}

BOOL flex_midextend(flex_ptr anchor, int at, int by)
{
  flex__rec *p;
  flex__rec *next;

  tracef3("flex_midextend %i at=%i by=%i.\n", (int) anchor, at, by);
  flex__check();

  p = ((flex__rec*) *anchor) - 1;
  if (p->anchor != anchor) {
    flex__fail(1);
  }
  if (at > p->size) {
    flex__fail(2);
  }
  if (by < 0 && (-by) > at) {
    flex__fail(3);
  }
  if (by == 0) {
    /* do nothing */
  } else if (by > 0) { /* extend */

    int growth = roundup(p->size + by) - roundup(p->size);
    /* Amount by which the block will actually grow. */

    if (! flex__ensure(growth)) {
      return FALSE;
    };

    next = (flex__rec*) (((char*) (p + 1)) + roundup(p->size));
    /* The move has to happen in two parts because the moving
    of objects above is word-aligned, while the extension within
    the object may not be. */

    flex__reanchor(next, growth);

    memmove(
      ((char*) next) + roundup(growth),
      next,
      flex__freep - (char*) next);

    flex__freep += growth;

    memmove(
      ((char*) (p + 1)) + at + by,
      ((char*) (p + 1)) + at,
      p->size - at);
    p->size += by;

  } else { /* The block shrinks. */
    int shrinkage;

    next = (flex__rec*) (((char*) (p + 1)) + roundup(p->size));

    by = -by; /* a positive value now */
    shrinkage = roundup(p->size) - roundup(p->size - by);
      /* a positive value */

    memmove(
      ((char*) (p + 1)) + at - by,
      ((char*) (p + 1)) + at,
      p->size - at);
    p->size -= by;

    flex__reanchor(next, - shrinkage);

    memmove(
      ((char*) next) - shrinkage,
      next,
      flex__freep - (char*) next);

    flex__freep -= shrinkage;

    flex__give();

  };
  return TRUE;
}

int flex__budge(int n, void **a)
/* The underlying system asks us to move all flex store up (if n +ve) or
down by n bytes. If you succeed, put the store allocated in *a and return
the size. size >= roundup(n) on successful exit, and will be a multiple of
four. If you fail, return 0. If n is -ve, no result is required: success is
assumed. */
{
  tracef1("flex__budge %i.\n", n);

  flex__check();

  if (n >= 0) /* all moving up */
  {
    int roundupn = roundup(n);

    if (flex__ensure(roundupn))
    {
      tracef0("flex__budge: moving up.\n");
      flex__reanchor((flex__rec*) flex__base, roundupn);
      memmove(
	flex__base + roundupn,
	flex__base,
	flex__freep - flex__base);
      *a = flex__base;
      flex__base += roundupn;
      flex__freep += roundupn;
      tracef1("flex__budge: success, %i bytes moved.\n", flex__freep - flex__base);
      return(roundupn);
    } else {
      tracef0("flex__budge: fail, not enough space.\n");
    };
  } else { /* all moving down */
    int roundupn = roundup(-n); /* a +ve value */

    tracef0("flex__budge: moving down.\n");
    flex__reanchor((flex__rec*) flex__base, -roundupn);
    memmove(
      flex__base - roundupn,
      flex__base,
      flex__freep - flex__base);
    flex__base -= roundupn;
    flex__freep -= roundupn;
    tracef0("flex__budge: moved down.\n");
  };
  return(0);
}

#if 0
int flex_storefree(void)
{
  /* totally imaginary, controlled/displayed by OS. */
  return(0);
}
#endif

void flex_init(void)
{
  flex__lim = (char*) -1;
  flex__wimpslot(&flex__lim);

#if TRACE
  flex__start =
#endif

  flex__freep = flex__lim;
  flex__base = flex__freep;
  _kernel_register_slotextend(flex__budge);
  tracef1("flex__lim = %i.\n", (int) flex__lim);
  flex__initialised = 1;

  /* Check that we're in the Wimp environment. */
  {
    void *a;
    if (! flex_alloc(&a, 1)) {
      werr(TRUE, msgs_lookup("flex2:Not enough memory, or not within *desktop world."));
    };
    flex_free(&a);
  };

}

#else

/* This is a temporary implementation, it simply goes to malloc.
Extension is done by copying, with the inevitable fragmentation resulting,
as you would expect. It is portable C, so would be useful when porting
to a different system. */

typedef struct {
  flex_ptr anchor;	/* *anchor should point back to here. */
  int size;		/* in bytes. Exact size of logical area. */
			/* then the actual store follows. */
} flex__rec;

#define GUARDSPACE 10000
/* We always insist on this much being left before returning space from
flex. This guards against malloc falling over. */

static void flex__fail(int i)
{
  werr(TRUE, "fatal store error fl-1-%i.", i);
}

static int flex__min(int a, int b)
{
  if (a < b) {return(a);} else {return(b);};
}

int flex_alloc(flex_ptr anchor, int n)
{
  char *guard = malloc(GUARDSPACE);
  flex__rec *p;
  BOOL result;

  tracef2("flex_alloc %i %i.\n", (int) anchor, n);
  if (guard == 0) guard = malloc(GUARDSPACE);
  if (guard == 0) {
    *anchor = 0;
    return 0;
  };
  p = malloc(n + sizeof(flex__rec));
  if (p == 0) p = malloc(n + sizeof(flex__rec));
  if (p==0) {
    result = FALSE;
  } else {
    p->anchor = anchor;
    p->size = n;
    *anchor = p + 1; /* sizeof(flex__rec), that is */
    result = TRUE;
  };
  free(guard);
  if (result == 0) *anchor = 0;
  return result;
}

void flex_free(flex_ptr anchor)
{
  flex__rec *p = ((flex__rec*) *anchor) - 1;
  if (p->anchor != anchor) {
    flex__fail(0);
  }
  free(p);
  *anchor = 0;
}

int flex_size(flex_ptr anchor)
{
  flex__rec *p = ((flex__rec*) *anchor) - 1;
  if (p->anchor != anchor) {
    flex__fail(4);
  }
  return(p->size);
}

int flex_extend(flex_ptr anchor, int newsize)
{
  flex__rec *p = ((flex__rec*) *anchor) - 1;
  return(flex_midextend(anchor, p->size, newsize - p->size));
}

BOOL flex_midextend(flex_ptr anchor, int at, int by)
{
  char *guard = malloc(GUARDSPACE);
  flex__rec *p;
  BOOL result = TRUE;

  if (guard == 0) guard = malloc(GUARDSPACE);
  if (guard == 0) return FALSE;
  p = ((flex__rec*) *anchor) - 1;
  if (p->anchor != anchor) {
    flex__fail(1);
  }
  if (at > p->size) {
    flex__fail(2);
  }
  if (by < 0 && (-by) > at) {
    flex__fail(3);
  }
  if (by == 0) {
    /* do nothing */
  } else {
    flex__rec *p1 = malloc(p->size + by + sizeof(flex__rec));
    if (p1 == 0) p1 = malloc(p->size + by + sizeof(flex__rec));
    if (p1 == 0) {
      result = FALSE;
    } else {
      (void) memcpy(
	/* to */ p1 + 1,
	/* from */ p + 1,
	/* nbytes */ flex__min(at, at + by));
      (void) memcpy(
	/* to */ at + by + (char*) (p1 + 1),
	/* from */ at + (char*) (p1 + 1),
	/* nbytes */ p->size  - at);
      p1->anchor = anchor;
      p1->size = p->size + by;
      *anchor = p1 + 1;
    }
  };
  free(guard);
  return result;
}

int flex_storefree(void)
{
  /* totally imaginary, at the moment. */
  return(0);
}

void flex_init(void)
{
  char *guard = malloc(GUARDSPACE);
  char foo[10000];
  if (guard == 0) werr(TRUE, "Not enough space.");
  foo[123] = 0;
  free(guard);
}

#endif

/* end */

