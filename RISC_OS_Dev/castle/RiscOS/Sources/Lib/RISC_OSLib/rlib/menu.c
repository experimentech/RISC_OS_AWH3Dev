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
/************************************************************************/
/* � Acorn Computers Ltd, 1992.                                         */
/*                                                                      */
/* This file forms part of an unsupported source release of RISC_OSLib. */
/*                                                                      */
/* It may be freely used to create executable images for saleable       */
/* products but cannot be sold in source form or as an object library   */
/* without the prior written consent of Acorn Computers Ltd.            */
/*                                                                      */
/* If this file is re-distributed (even if modified) it should retain   */
/* this copyright notice.                                               */
/*                                                                      */
/************************************************************************/

/* Title: c.menu
 * Purpose: menu manipulation.
 * History: IDJ: 06-Feb-92: prepared for source release
 */

#define BOOL int
#define TRUE 1
#define FALSE 0

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "os.h"
#include "wimp.h"
#include "werr.h"
#include "menu.h"

#include "sprite.h"
#include "resspr.h"
#include "msgs.h"
#include "VerIntern/messages.h"

typedef struct menu__str {
  wimp_menuhdr *m;         /* the wimp-level menu that we've built. */
  int nitems;              /* items in menu */
  void *entryspace;        /* for sub-menus, and entries with >12 chars */
  int nbytes;              /* bytes used in entryspace */
  int maxentrywidth;       /* used to set menu width */
  int maxitems;            /* max items for menu_new/extend */
  int maxbytes;            /* max bytes for menu_new/extend */
} menu__str;
/* concrete representation of abstract menu object */

/* The menu__str structure points to a RISCOS-style menu, and to a separate
buffer of workspace for sub-menu pointers and for string fields that
are >12 characters. The format of the entryspace is:
  each sub-Menu pointer
  a Menu(NIL) word
  each entry buffer
*/

static wimp_menuitem *menu__itemptr(menu m, int n)
/* Pointer to the nth item in the menu (starting at 0). */
{
  return(((wimp_menuitem*)(m->m + 1)) + n);
}

/* -------- Building RISC OS Menus. -------- */

/* The menu is assembled entry by entry in malloc'd storage.
The two main areas hold the menu block and the indirect data.
At the start of menu_new or menu_extend they are (re)allocated too
large, then shrunk using realloc before exit.
If realloc causes the indirect area to move, any indirect pointers
in the menu block are adjusted.
The total space is only limited by memory. */

/* The following set the amount of storage to be allocated in one go. */

#define ADDITEMS  32       /* items added in one chunk for menu block */
#define ADDBYTES 512       /* bytes added in one chunk for indirect text */


static void menu__disposespace(menu m)
{ /* Free two areas (header+icons & indirect data) for a complete menu */
  if (m->m != NULL) {
    free(m->m);
    m->m = 0;
  }
  if (m->entryspace != NULL) { /* can only happen with very new menu__strs. */
    free(m->entryspace);
    m->entryspace = 0;
  }
}

static void menu__checkmove(menu m, int moveoffset)
{ /* Move any indirect pointers in menu items by moveoffset */
  int i;

  for (i=0;i<m->nitems;i++) {
    wimp_menuitem *ptr = menu__itemptr(m, i);
    if (ptr->iconflags & wimp_INDIRECT) {
      ptr->data.indirecttext.buffer += moveoffset;
    }
  }
}

static void menu__realloc(menu m, int items, int bytes)
/* Change sizes for more (or less) menu items and bytes indirect data.
   Note areas may move when extended (or even shrunk?) */
{
  int  *oldesp; /* for old entryspace addr */

  if (items != 0) {
    m->maxitems += items;
    m->m = realloc(m->m, sizeof(wimp_menuhdr) + m->maxitems * sizeof(wimp_menuitem));
    if (m->m == NULL)
      werr(TRUE, msgs_lookup(MSGS_menu1)); /* not enough memory */
  }
  if (bytes != 0) {
    m->maxbytes += bytes;
    oldesp = m->entryspace;
    m->entryspace = realloc(m->entryspace, m->maxbytes);
    if (m->entryspace == NULL) {
      werr(TRUE, msgs_lookup(MSGS_menu1)); /* not enough memory */
    }
    if ((oldesp != m->entryspace) && (m->nitems>0)) {
      menu__checkmove(m, (int)m->entryspace - (int)oldesp);
    }
  }
}

/* -------- Creating menu descriptions. -------- */

static menu menu__initmenu(char *name)
{ /* Create and initialise menu structure, block and entryspace */
  menu m;
  int i;

  m = calloc(1,sizeof(menu__str));
  if (m == NULL) {
    werr(TRUE, msgs_lookup(MSGS_menu1));
  }

  menu__realloc(m, ADDITEMS, ADDBYTES);

  /* insert a NIL in the entrySpace to distinguish sub-Menu pointers
  from text space. */
  m->nbytes = 4;
  *((int*)m->entryspace) = 0;

  for (i=0; i<12; i++) {
    m->m->title[i] = name[i];
    if (name[i]==0) {break;}
  }
  m->m->tit_fcol = 7; /* title fore: black */
  m->m->tit_bcol = 2;  /* title back: grey */
  m->m->work_fcol = 7; /* entries fore */
  m->m->work_bcol = 0; /* entries back */
  m->m->width = i*16;  /* minimum value */
  m->m->height = 44;   /* per entry */
  m->m->gap = 0;       /* gap between entries, in OS units */
  return m;
}

static int menu__max(int a, int b)
  { if (a < b) {return(b);} else {return(a);} }

static wimp_menuitem *menu__additem(
  menu m /*out*/, char *name, int length)
/* Add an item to the end of a menu                    */
/* The returned pointer can be used to set flags, etc. */
{
  wimp_menuitem *ptr;
  if (m->nitems == m->maxitems) {
    menu__realloc(m, ADDITEMS, 0);
  }
  ptr = menu__itemptr(m, m->nitems++);
  ptr->flags = 0;
  ptr->submenu = (wimp_menustr*) -1;
  ptr->iconflags = wimp_ITEXT + wimp_IFILLED + wimp_IVCENTRE + (7*wimp_IFORECOL);
  if (length > m->maxentrywidth) {
    m->maxentrywidth = length;
    m->m->width = menu__max(m->m->width, 16 + length * 16);
      /* in OS units, 16 per char. */
  }
  if (length <= 12) {
    /* item can be directly in the icon, so copy to icon block. */
    int i;
    for (i=0; i<length; i++) {ptr->data.text[i] = name[i];}
    if (length < 12) {ptr->data.text[length] = 0;}
  } else {
    if (length+1+m->nbytes >= m->maxbytes) {
      /* new length over current maximum, so add storage */
      menu__realloc(m, 0, ADDBYTES);
    }
    /* space for length, so set up icon block to be indirect */
    ptr->iconflags += wimp_INDIRECT;
    ptr->data.indirecttext.buffer = ((char*)m->entryspace) + m->nbytes;
    ptr->data.indirecttext.validstring = (char*) -1;
    ptr->data.indirecttext.bufflen = 100;
    /* copy name into entryspace */
    (void) memmove(((char*)m->entryspace) + m->nbytes, name, length);
    m->nbytes += length + 1;
    ((char*)m->entryspace)[m->nbytes-1] = 0; /* terminate the string. */
  }
  return(ptr);
}

/* -------- Parsing Description Strings. -------- */

static void menu__syntax(void)
{
  /* General policy: be lenient on syntax errors, so do nothing */
}

typedef enum {
  TICK = 1,
  FADED = 2,
  DBOX = 4,
  NUM  = 8
} opt;

typedef enum {OPT, SEP, NAME, END} toktype;

typedef struct {
  char *s;
  toktype t;
  char ch;        /* last separator char encountered */
  opt opts;       /* last opts encountered */
  char *start;
  char *end;      /* last name encountered */
} parser;

static void menu__initparser(parser *p, char *s)
{
  p->s = s;
  p->ch = ',';
}

static void menu__getopt(parser *p)
{
  p->opts = 0;
  while (p->ch=='!' || p->ch=='~' || p->ch=='>' || p->ch=='#' || p->ch==' ') {
    if (p->ch=='!') {
      p->opts |= TICK;
    } else if (p->ch=='~') {
      p->opts |= FADED;
    } else if (p->ch=='#') {
      p->opts |= NUM;
    } else if (p->ch=='>') {
      p->opts |= DBOX;
    }
    p->ch=*p->s++;
  }
  p->s--;
}

static void menu__getname (parser *p)
{ /*Skip leading spaces*/
  while (p->ch == ' ')
    p->ch = *p->s++;

  p->start = p->s - 1;

  if (p->ch == '"')
  { /*Quoted string*/
    p->ch = *p->s++;

    p->start = p->s - 1;

    while (p->ch != 0 && p->ch != '"')
      p->ch = *p->s++;

    p->end = p->s - 1;

    if (p->ch == '"')
    { p->ch = *p->s++;

      /*Skip trailing spaces*/
      while (p->ch == ' ')
        p->ch = *p->s++;
    }

    if (p->ch != 0 && p->ch != ',' && p->ch != '|')
      p->ch = *p->s++;

    p->s--;
  }
  else
  { /*Non-quoted string*/
    p->start = p->s - 1;

    while (p->ch != 0 && p->ch != ',' && p->ch != '|')
      p->ch = *p->s++;

    p->end = --p->s;
  }
}

static toktype menu__gettoken(parser *p)
{
  p->ch = ' ';
  while (p->ch == ' ') p->ch = *p->s++;
  switch (p->ch) {
  case 0:
    p->t = END;
    break;
  case '!':
  case '~':
  case '>':
  case '#':
    p->t = OPT;
    menu__getopt(p);
    break;
  case ',':
  case '|':
    p->t = SEP;
    break;
  default:
    p->t = NAME;
    menu__getname(p);
    break;
  }
  return(p->t);
}

/* -------- Parsing and Extension. -------- */

static void menu__doextend(menu m, char *descr)
{
  parser p;
  toktype tok;
  wimp_menuitem *ptr;

  menu__initparser(&p, descr);
  tok = menu__gettoken(&p);
  if (tok==END) {
    /* do nothing */
  } else {
    if (tok==SEP) {
      if (m->nitems == 0) {
        menu__syntax();
      } else {
        if (p.ch == '|') {
          ptr = menu__itemptr(m, m->nitems-1);
          ptr->flags |= wimp_MSEPARATE;
        }
        tok = menu__gettoken(&p);
      }
    }
    while (1) {
      if (tok == OPT) {
        tok = menu__gettoken(&p); /* must be NAME, check below */
      } else {
        p.opts = 0;
      }
      if (p.t != NAME) {
        menu__syntax();
      } else {
        ptr = menu__additem(m, p.start, p.end - p.start);
        if ((TICK & p.opts) != 0) {
          ptr->flags |= wimp_MTICK;
        }
        if ((FADED & p.opts) != 0) {
          ptr->iconflags |= wimp_INOSELECT;
        }
        if ((NUM & p.opts) != 0) {
          ptr->iconflags |= (1<<20);
        }
        if ((DBOX & p.opts) != 0) {
          ptr->flags |= wimp_MSUBLINKMSG;
          ptr->submenu = (wimp_menustr*) 1;
        }
        tok = menu__gettoken(&p);
        if (tok == END) break;
        if (tok != SEP) {
          menu__syntax();
        } else {
          if (p.ch == '|') ptr->flags |= wimp_MSEPARATE;
        }
      }
      tok = menu__gettoken(&p);
    }
  }
}

/* -------- Entrypoints. -------- */

menu menu_new(char *name, char *descr)
{ /* Create a new menu from the list of entries in descr */
  menu m;
  wimp_menuitem *ptr;

  m = menu__initmenu(name);
  menu__doextend(m, descr); /* create menu entrie(s) from descr */
  menu__realloc(m, m->nitems-m->maxitems, m->nbytes-m->maxbytes); /* shrink */
  if (m->nitems > 0) {
    menu__itemptr(m, m->nitems-1)->flags |= wimp_MLAST; /* set last */
  }
  if (strlen(name) > 12) { /* check title */
      *(char **)m->m->title = name;
      ptr = menu__itemptr(m, 0);
      ptr->flags |= wimp_MINDIRECTED;
  }
  return m;
}

void menu_dispose(menu *m, int recursive)
{ /* Free the storage associated with a menu - and optionally submenus. */
  if (recursive != 0) {
    menu *a = (menu*) ((*m)->entryspace);
    while (1) {
      menu subm = *(a++);
      if (subm == 0) {break;}
      menu_dispose(&subm, 1);
    }
  }
  menu__disposespace(*m);
  free(*m);
}

void menu_extend(menu m, char *descr)
{ /* Add one (or more) items from descr to existing menu. */
  menu__realloc(m, ADDITEMS, ADDBYTES);
  menu__itemptr(m, m->nitems-1)->flags &= ~wimp_MLAST; /* unset last */
  menu__doextend(m, descr); /* add menu item(s) from descr */
  menu__realloc(m, m->nitems-m->maxitems, m->nbytes-m->maxbytes); /* shrink */
  if (m->nitems > 0) {
    menu__itemptr(m, m->nitems-1)->flags |= wimp_MLAST; /* set new last */
  }
}

void menu_setflags(menu m, int entry, int tick, int fade)
{ /* Set/Unset tick and fade flags on specific menu entry */
  wimp_menuitem *p;
  if (entry == 0) {return;}
  if (entry > m->nitems) {return;}
  p = menu__itemptr(m, entry-1);
  if (tick != 0) {
    p->flags |= wimp_MTICK;
  } else {
    p->flags &= ~wimp_MTICK;
  }
  if (fade != 0) {
    p->iconflags |= wimp_INOSELECT;
  } else {
    p->iconflags &= ~wimp_INOSELECT;
  }
}

void menu_setcolours(menu m, int entry, int fore, int back)
{
  wimp_menuitem *p;
  if (entry == 0) {return;}
  if (entry > m->nitems) {return;}
  p = menu__itemptr(m, entry-1);
  if (p->iconflags & wimp_IFONT) {return;} /* Dual field use */
  p->iconflags = (p->iconflags & ~((15 * wimp_IFORECOL) | (15 * wimp_IBACKCOL)))
                 | (fore * wimp_IFORECOL)
                 | (back * wimp_IBACKCOL);
}

void menu_make_writeable(menu m, int entry, char *buffer, int bufferlength,
                         char *validstring)
{
  wimp_menuitem *p;
  if (entry == 0) {return;}
  if (entry > m->nitems) {return;}
  p = menu__itemptr(m, entry-1);
  p->flags |= wimp_MWRITABLE ;
  p->iconflags |= wimp_BWRITABLE * wimp_IBTYPE + wimp_INDIRECT +
                  wimp_IHCENTRE + wimp_IVCENTRE + wimp_ITEXT ;
  p->data.indirecttext.buffer = buffer ;
  p->data.indirecttext.bufflen = bufferlength ;
  p->data.indirecttext.validstring = validstring ;
}


void menu_make_sprite(menu m, int entry, char *spritename)
{
  wimp_menuitem *p;
  if (entry == 0) {return;}
  if (entry > m->nitems) {return;}
  p = menu__itemptr(m, entry-1);


  p->iconflags &= ~wimp_ITEXT;
  p->iconflags |= wimp_INDIRECT+wimp_IVCENTRE+wimp_ISPRITE;
  p->data.indirectsprite.name = spritename;
  p->data.indirectsprite.spritearea = resspr_area();
  p->data.indirectsprite.nameisname = 1;
}


void menu_submenu(menu m, int place, menu submenu)
{ /* Link a submenu to an entry in a parent menu */
  wimp_menuitem *p = menu__itemptr(m, place-1);

  p->submenu = (wimp_menustr*) (submenu?submenu->m:NULL);
  menu__realloc(m, 0, sizeof(menu*));
  (void) memmove(
    /* to   */ ((menu*) m->entryspace) + 1, /* +4 bytes */
    /* from */ ((menu*) m->entryspace),
    m->nbytes);
  m->nbytes += sizeof(menu*);
  *((menu__str**)(m->entryspace)) = submenu;
  menu__checkmove(m, sizeof(menu*)); /* adjust indirect ptrs for insertion */
}

void *menu_syshandle(menu m)
{
  if (m != NULL)
    return (void *)m->m;
  return (void *)-1;  
}

/* end */
