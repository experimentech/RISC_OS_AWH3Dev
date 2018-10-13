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
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "swis.h"

#include "module.h"
#include "tags.h"
#include "msgfile.h"
#include "PortMan.h"
#include "messages.h"


static struct msgfile tagsfile = MSGFILE_INIT;

typedef struct tag_pair tag_pair;

#define TOKEN_MAX_SIZE 16

struct tag_pair {
    tag_pair*       next;
    char            name[TOKEN_MAX_SIZE];
    struct bitdef   result;
};

static tag_pair* head_tag = 0;

/*
 * Get an integer from *str, updating *str to point to the end.  Returns
 * 1 (true) if an integer was read.
 */
static
int
get_int(const char **str, unsigned long *result)
{
  const char *begin;

  if(*str==NULL)
  {
    *result=0;
    return 0;
  }

  /* Skip whitespace */
  *str+=strspn(*str, " \t");

  switch(**str)
  {
  case '\r': case '\n': case 0:
    *result=0;
    return 0;
  case '&':
    *result=strtoul(begin=*str+1, (char**)str, 16);
    break;
  default:
    *result=strtoul(begin=*str, (char**)str, 0);
    break;
  }
  return *str!=begin;
}

/*
 * Gets a field separator from *str, updating *str to point to the end of
 * the separator.  Returns 1 (true) if a separator was read.  Sets *str
 * to NULL on error.
 */

static
int
get_sep(const char **str)
{
  if(*str==NULL)
    return 0;

  /* Skip whitespace */
  *str+=strspn(*str, " \t");

  switch(**str)
  {
  /* End of line */
  case '\r': case '\n': case 0:
    return 0;
  case ':':
    ++*str;
    return 1;
  default:
    *str=NULL;
    return 0;
  };
}

/* Format of line:
 *   <bit>:[port]:[flags]
 */

static
_kernel_oserror *
parse_line(struct bitdef *bit, const char *line)
{
  unsigned long num;

  /* Gobble the bit number */
  if(!get_int(&line, &num))
    return msgfile_error_lookup(&messages, PortMan_BadLine, BadLine);

  bit->num=(int)num;

  /* Fill in the defaults. */
  bit->flags=0;
  bit->port=0;

  /* Gobble the separator */
  if(!get_sep(&line))
  {
    if(line==NULL)
      return msgfile_error_lookup(&messages, PortMan_BadLine, BadLine);
    return NULL;
  }

  /* Get and check port number */
  if(get_int(&line, &num))
    bit->port=(int)num;

  /* Gobble the separator */
  if(!get_sep(&line))
  {
    if(line==NULL)
      return msgfile_error_lookup(&messages, PortMan_BadLine, BadLine);
    return NULL;
  }

  /* Get the flags */
  if(get_int(&line, &num))
    bit->flags=(int)num;

  /* Check for errors at the end of the line */
  get_sep(&line);

  if(line==NULL)
    return msgfile_error_lookup(&messages, PortMan_BadLine, BadLine);
  return NULL;
}

_kernel_oserror *
tag_get(struct bitdef *result, const char *name)
{
  tag_pair *t = head_tag;
  while (t) {
      int l = strlen (t->name);
      /* the string can be terminated by control */
      if (strncmp (name, t->name, l) == 0 && (name[l] <= ' ')) {
          *result = t->result;
          return 0;
      }
      t = t->next;
  }

  return msgfile_error_lookup(&messages, PortMan_NoTag, NoTag, name);
}

void tag_foreach(void (*fn)(const char *name, struct bitdef bit))
{
  for (tag_pair *t = head_tag; t; t = t->next)
    fn(t->name, t->result);
}

void tag_close(void)
{
  tag_pair* t = head_tag, *tt;
  while (t) {
    tt = t->next;
    free (t);
    t = tt;
  }
  head_tag = 0;
}

_kernel_oserror* tag_init(void)
{
  _kernel_oserror* err;
  int index = 0;
  int length = 0;
  const char *line;
  char name[TOKEN_MAX_SIZE];
  int more = 0;
  tag_pair **t = &head_tag;
  err=msgfile_open( &tagsfile, TAGS_FILE );
  if(err)
    return err;

  do {
    err = _swix (MessageTrans_EnumerateTokens, _INR(0, 4) | _OUTR(2, 4),
      &tagsfile.buf[0], "*", &name[0], TOKEN_MAX_SIZE, index,
      &more, &length, &index);
    if (err) goto error1;

    if (more) {
      *t = malloc(sizeof **t);
      if (*t == 0) {
        err = msgfile_error_lookup(&messages, PortMan_BadLine, BadLine);
        goto error1;
      }

      (*t)->next = 0;
      strncpy ((*t)->name, name, length+1);

      err=msgfile_lookup( &tagsfile, &line, name );
      if(err)
          goto error2;

      /* if there's an error parsing the line then just skip this entry */
      err=parse_line(&((*t)->result), line);
      if (err) {
          free (*t);
          continue;
      }

      t = &(*t)->next;
    }
  } while (more);

  msgfile_close (&tagsfile);

  return 0;
error2:
  free (*t);
  (*t) = 0;
error1:
  msgfile_close (&tagsfile);
  return err;

}
