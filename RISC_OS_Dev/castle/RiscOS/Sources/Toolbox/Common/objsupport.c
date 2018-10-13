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
/* File:        objsupport.c
 * Purpose:     Support Library for object modules
 * Author:      Neil Kelleher
 * History:     1-Jul-1994:  NK: created
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include "kernel.h"
#include "swis.h"

#include "debug.h"
#include "objects/toolbox.h"
#include "objects/window.h"
#include "mem.h"
#include "objsupport.h"
#include "string32.h"

static _kernel_oserror *extract_gadget_info(char *tm,ComponentID id,void **p,int *l)
{
   return _swix(Window_ExtractGadgetInfo, _INR(0,2) | _OUTR(0,1), 0,tm,id, p,l);
}

char *copy_template(char *name)
{
  char *tm;
  ObjectTemplateHeader *obj;
  if(_swix(Toolbox_TemplateLookUp, _INR(0,1) | _OUT(0),0,name,&obj)) tm = NULL;
  else {
    tm = mem_allocate(obj->total_size,"template copy");
    if(tm) {
      memcpy(tm,obj,obj->total_size);
      ((ObjectTemplateHeader *)tm)->body =
         (WindowTemplate *) (tm + ((int) ((WindowTemplate *) obj->body)) - ((int) obj));
      ((WindowTemplate *) (((ObjectTemplateHeader *)tm)->body))-> gadgets =
         (Gadget *) (tm + ((int) ((WindowTemplate *) obj->body)->gadgets) - ((int) obj));

    }
  }
  return tm;
}

_kernel_oserror *__zap_gadget(char *tm,ComponentID id,int off,int val)
{
   _kernel_oserror *e=NULL;
   int *p,l;
   e=extract_gadget_info(tm,id,(void **) &p,&l);
   if(!e) *(p+ off/sizeof(int)) = val;
   return e;

}

_kernel_oserror *__zap_gadget_string(char *tm,ComponentID id,int off,const char* val,int offlen)
{
   /* Zaps the string into the gadget template and checks the length against a length field
    * in the same template, increasing the value if necessary
    */
   int *p,l;
   _kernel_oserror *e=__zap_gadget(tm,id,off,(int)val);
   if (e) return e;
   e=extract_gadget_info(tm,id,(void **) &p,&l);
   if(!e) {
      int cl=*(p+ offlen/sizeof(int));
      int rl=string_length((char *)val)+1;
      if (cl<rl) e=__zap_gadget(tm,id,offlen,rl);
   }
   return e;

}

int *__read_gadget(char *tm,ComponentID id,int off)
{
   int *p,l;
   if (extract_gadget_info(tm,id,(void **)&p,&l) == NULL)
      return (p+ off/sizeof(int));
   else return 0;
}

_kernel_oserror *__zap_window(char *tm,int off,int val)
{
   char *p = (char *)((WindowTemplate *) (((ObjectTemplateHeader *)tm)->body));
   DEBUG debug_output("objsupport","zapping word +%x with %x\n",off,val);
   if ((((ObjectTemplateHeader *)tm)->version == 101) && (off >= offsetof(WindowTemplate,default_focus))) off -=24;
   * ((int *) (p+off)) =val;
   return NULL;
}

_kernel_oserror *create_from_template(char *template_id, ObjectID *handle)
{
   _kernel_oserror *er=NULL;
   if ((er=_swix(Toolbox_CreateObject, _INR(0,1) | _OUT(0),
       1,       /* flags */
       template_id,
       handle)) != NULL) {
           mem_free(template_id,"freeing template copy");
           return er;
       }

   mem_free(template_id,"freeing template copy");
   return NULL;
}

/* for word aligned overlapping areas */

static void _mem_cpy(char *a,char *b,int size)
{
  int *c=(int *)a;
  int *d=(int *)b;
  size = size/(sizeof(int));

  DEBUG debug_output("objsupport","Copying %d words from %x to %x\n",size,b,a);

  while (size>0) {
    size--;
    *c++ = *d++;
  }

}

_kernel_oserror *delete_gadget(char *tm,ComponentID id)
{
   _kernel_oserror *e=NULL;
   char *p;
   int l;
   ObjectTemplateHeader *obj = (ObjectTemplateHeader *)tm;

   e=extract_gadget_info(tm,id,(void **)&p,&l);
   if(!e) {
      DEBUG debug_output("objsupport","Deleting gadget from template: Template size %d, Gadget size %d\n",obj->total_size,l);
      DEBUG debug_output("objsupport","about to copy %d bytes\n",(obj->total_size) - (((int)p) - ((int)tm)) -l);
      _mem_cpy(p,p+l,(obj->total_size) - (((int)p) - ((int)tm)) -l);
      (obj->total_size) -= l;
      (((WindowTemplate *)obj->body)->num_gadgets) -= 1;
   }
   return e;

}

int *__read_window(char *tm,int off)
{
   char *p = (char *)((WindowTemplate *) (((ObjectTemplateHeader *)tm)->body));
   DEBUG debug_output("objsupport","reading word +%x \n",off);
   if ((((ObjectTemplateHeader *)tm)->version == 101) && (off >= offsetof(WindowTemplate,default_focus))) off -=24;
   return ((int *) (p+off));

}
