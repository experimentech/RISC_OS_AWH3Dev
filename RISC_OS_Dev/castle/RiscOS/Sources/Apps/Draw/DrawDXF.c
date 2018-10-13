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
/* > DrawDXF.c
 *
 * Read DXF files into Draw
 *
 * Author: David Elworthy
 * Version: 0.54
 * History: 0.00 -  6 July 1988 - first stab
 *          0.10 -  19 July 1988
 *          0.20 -  26 July 1988 - load point added, true colours
 *          0.30 -  29 July 1988 - black bug fix
 *          0.40 -   4 Aug  1988 - always load at mouse location
 *          0.41 -   8 Aug  1988 - RAM transfers
 *          0.50 -  2x Sept 1988 - Alpha test bug fixes
 *          0.51 -  13 June 1989 - upgraded to drawmod and visdelay
 *                  16 June 1989 - upgraded to msgs
 *          0.52 -  23 June 1989 - bug 2008 fixes, use heap instead of malloc
 *          0.53 -  27 June 1989 - rework of INSERT code, scaling, base point
 *          0.54 -  28 June 1989 - substantial rework
 *                                 force origin on to page
 *
 * Some support for line types is included, even though we don't make any
 * use of them at present.
 *
 * Convention: on an error, the routine reports it and replies FALSE. The
 * rendering of the file must then be abandoned. Some of the error messages
 * could be removed.
 *
 * Because of default values, we may have read one group ahead of where we
 * should be. The read routines allow for this by keeping a 'pending read'
 * flag, and loading values from globals instead of reading if it is set.
 *
 * Various options such as the file origin and units are set on the basis of
 * a dialogue box, and then adjusted according to the coordinate system of
 * the file.
 *
 * Reading is line by line for file I/O, and from a block for RAM I/O. This
 * may changed eventually.
 *
 * The general approach is that at any instant there is a base point, which
 * is either the origin or the base point of a block. We create objects
 * relative to this point, scaling into draw units. When the block, or the
 * whole of the entities have been created, they are scaled and shifted as a
 * whole into the destination space.
 * This could be further extended to make rendering of inserts more efficient.
 *
 * Unimplemented features:
 *  text is in a single font - could use multiple styles
 *  text justification is approximate in proportional fonts
 *  many text features cannot be implemented
 *  the following object classes are not implemented at all:
 *    SHAPE, ATTDEF, ATTRIB, 3DLINE, 3DFACE, DIMENSION
 *  the style table is ignored
 *  line type is not used
 *  polylines do not use: end widths, curve fitting
 *  inserts do not use: column and row values, attributes entries,
 *  and z scaling.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "os.h"
#include "wimp.h"
#include "flex.h"
#include "heap.h"
#include "werr.h"
#include "xferrecv.h"
#include "visdelay.h"
#include "msgs.h"
#include "bezierarc.h"
#include "dbox.h"
#include "help.h"
#include "drawmod.h"
#include "jpeg.h"
#include "font.h"

#include "ftrace.h"
#include "guard.h"

#include "Draw.h"
#include "DrawCheck.h"
#include "DrawFileIO.h"
#include "DrawObject.h"
#include "DrawDXF.h"

#if TRACE
  #define DEBUG(s) \
    ftracef2 \
    ( "%s *%d*", \
      s, dxf__diag && dxf__diag->misc? dxf__diag->misc->stacklimit - \
          dxf__diag->misc->ghostlimit: 0 \
    );
#else
  #define DEBUG(s)
#endif

/*Size used for all buffers*/
#define dxf__maxBuffer 256

/*Codes for BYBLOCK and BYLAYER in colours*/
#define DXF__BYBLOCK 0
#define DXF__BYLAYER 256

/*
 Data Group  : type for points at double precision
 Description :
*/

typedef draw_doublecoord dxf__coord;

/*
 Data Group  : diagram record from Draw
 Description : copied into from parameter passed by Draw
*/

static diagrec *dxf__diag;

/*
 Data Group  : system variables tables
 Description : there are four tables, for integers, floating point values,
               coordinates and strings. Each has various symbolic indices
               defined for the variables. Each table appears as a union of
               an array and a structure. The array form has specified
               symbolic indices, which are used when reading the system
               variables.
*/

/*Integer type*/
#define DXF__maxVarInt 7
static union
{   struct
    {   int angdir;
        int cecolor;
        int gridmode;
        int osmode;
        int snapmode;
        int blockcolour;              /*Current of current block*/
        int blocklineType;            /*Line type of current block*/
    } s;
    int a [DXF__maxVarInt];
}   dxf__varInt;

#define DXF__angdir 0
#define DXF__cecolor 1
#define DXF__gridmode 2
#define DXF__osmode 3
#define DXF__snapmode 4
/*#define DXF__blockcolour 5 not needed*/
/*#define DXF__blocklineType 6 not needed*/

/*Floating point type*/
#define DXF__maxVarFloat 3
static union
{   struct
    {   double angbase;
        double plinewid;
        double blockthickness;           /*Line thickness for current block*/
    } s;
    double a [DXF__maxVarFloat];
}   dxf__varFloat;

#define DXF__angbase 0
#define DXF__plinewid 1
/*#define DXF__blockthickness 2 not needed*/

/*Coordinate (point) type*/
#define DXF__maxVarCoord 6
static union
{   struct
    {   dxf__coord gridunit;
        dxf__coord limmax;
        dxf__coord limmin;
        dxf__coord snapunit;
        dxf__coord textsize;
        dxf__coord viewctr;
    } s;
    dxf__coord a [DXF__maxVarCoord];
}   dxf__varCoord;

#define DXF__gridunit 0
#define DXF__limmax 1
#define DXF__limmin 2
#define DXF__snapunit 3
#define DXF__textsize 4
#define DXF__viewctr 5

/*String type*/
/*There is a slot here for each string variable we actually use. If further
string variables are to be handled in future, extend the structure.*/
#define DXF__maxVarString 2
static union
{   struct
    {   char *celtype;
        char *clayer;
    } s;
    char *a [DXF__maxVarString];
}   dxf__varString;

#define DXF__celtype 0
#define DXF__clayer 1

/*Constant names*/
static char *dxf__default_celtype = "BYBLOCK";
static char *dxf__default_clayer  = "_0";

/*
 Data Group  : line types table
 Description : records the line type names. Space allocated in table reading.
               A NULL pointer terminates the table.
*/

static char **dxf__lineTypes;

/*
 Data Group  : layers table and typedef
 Description : layer names and data. The last entry is followed by an entry
               with a null name, and the colour and line type set to the system
               defaults.
*/

typedef struct
{   char *name;
    int colour;
    int lineType;          /*Index into line type table. -1 if not known*/
}   dxf__layerStruct;

static dxf__layerStruct *dxf__layers;

/*
 Group       : decoder table
 Description : typedef for decoder table. See dxf__decodeByTable. A null string
               marks the end of the table. The extra field is used for holding
               a further piece of information needed for some tables.
*/

typedef struct
{   char *value;
    int action;
    int extra;
}   dxf__decoderTable;

/*
 Data Group  : unit conversion
 Description : conversion from DXF units to draw units, for millimetres and
               inches, plus a flag for it. Also base unit multiplier.
*/

#define DXF__inches       dbc_OneInch
#define DXF__millimetres  (dbc_OneCm/10)

static double DXFtoDraw = DXF__millimetres;
static BOOL dxf__millimetres = TRUE;
static double dxf__baseUnit    = 1.0;

/*
 Data Group  : blocks record
 Description : blocks are held in a linked list.
               Each entry in the list contains the block name and a list
               of strings as read from the file, again as a linked list.
               When the block is rendered (by an INSERT), the lines are read
               from the list just as if they had come out of the file.
               The header information of the block (e.g. its linetype) is
               held in the block structure -- this values are loaded into
               the defaults on the INSERT.
*/

/*Structure for the items in a block*/
typedef struct dxf_s_item DXF__item;
struct dxf_s_item
{   int group;
    union
    {   int i;
        double f;
        char *s;
    } data;
    DXF__item *next;
};

/*Structure for each block*/
typedef struct dxf_s_block DXF__block;
static struct dxf_s_block
{   char *name;
    int colour;
    int linetype;
    double thickness;
    dxf__coord base;
    DXF__item *items;
    DXF__block *next;
} *dxf__blockHead, *dxf__blockTail;

/*
 Data Group  : coordinate context
 Description : consists of just the current base point
*/

typedef struct
{   dxf__coord base;
} dxf__context;

/*
 Data Group  : 'standard' font
 Description : name for default font.
*/

static char dxf__standardFont [dxf__maxBuffer] = "Trinity.Medium";
static int dxf__standardFontNumber = 0;

/*Last line number: gives an approximate location for errors*/
static int dxf__lineNumber;

/*A forward reference: mutual recursion with dxf__drawInsert*/
extern BOOL dxf__drawEntity (char *terminator, dxf__context *context);

/****************************************************************************
  Low level file reading routines, and miscellanea
 ****************************************************************************/

#define dxf__draw(dd) (int) (dd*DXFtoDraw)

static int dxf__cvtX (double xx, dxf__context *c)

{   return (int) ((xx - c->base.x) *DXFtoDraw);
}

static int dxf__cvtY (double yy, dxf__context *c)

{   return (int) ((yy - c->base.y) *DXFtoDraw);
}

/*Convert a coord - must use result immediately!*/
static draw_objcoord *dxf__cvt (dxf__coord *pt, dxf__context *c)

{   static draw_objcoord out;
  out.x = dxf__cvtX (pt->x, c);
  out.y = dxf__cvtY (pt->y, c);
  return &out;
}

/*
 Function    : dxf__transform
 Purpose     : transform a given part of a diagram
 Parameters  : start, end offsets of objects
               offset to apply to base (in draw units)
               scaling factors
               whole file flag
 Returns     : void
 Description : bounds the given objects, then maps them into the given space.
               If the whole file flag is set, then the objects are mapped to
               (0,0) plus the give move.
*/

static void dxf__transform (int start, int end, int movex, int movey,
                           dxf__coord *scale, BOOL whole_file)

{   draw_bboxtyp box;

    DEBUG ("[1 ");
  /*Bound the objects*/
  draw_obj_bound_objects (dxf__diag, start, end, (whole_file) ? &box : NULL);

  /*Form shift to either insert at right place or force to origin*/
  if (whole_file)
  {   movex  -= box.x0;
    movey  -= box.y0;
  }

  /*Scale and shift the objects*/
  draw_scale_Draw_file (dxf__diag, start,end, movex,movey, scale->x,scale->y);
    DEBUG (" 1]");
}

/*
 Data Group  : Source state
 Description : source state block: used for both current and saved states
*/

typedef struct
{   BOOL pendingRead;
  int group;
  int groupInt;
  double groupFloat;
  char groupString [dxf__maxBuffer];
  BOOL fromfile;
  FILE *file;
  DXF__block *block;
  DXF__item *item;
} dxf__state;

static dxf__state state =
{ FALSE,           /*pending read*/
  0, 0, 0.0, "",   /*group variables*/
  FALSE, NULL,     /*file state*/
  NULL,  NULL      /*block state*/
};

/*Flag - true for read via ram*/
static BOOL dxf__viaRam;

/*File buffer pointers*/
static char *dxf__fileBuffer = NULL;
static int dxf__fileLocation, dxf__fileEnd;

/*
 Function    : draw_dxf_setOptions
 Purpose     : get file options
 Parameters  : void
 Returns     : TRUE if file is to be read
 Description : a dialogue box is created and options read from it. If CLOSE
               or abandon are used to end the dialogue the FALSE is returned.

               The field numbers must match the #defines below.
               This must be called BEFORE a new window is opened, to avoid
               closing catastrophes.

               The options are left in globals.
*/

/*Defines for the fields*/
#define dxf_dbox_OK      ((dbox_field) 0)
#define dxf_dbox_Abandon ((dbox_field) 1)
#define dxf_dbox_milli   ((dbox_field) 2)
#define dxf_dbox_inch    ((dbox_field) 3)
#define dxf_dbox_unit    ((dbox_field) 4)
#define dxf_dbox_info    ((dbox_field) 5) /*Text output field*/
#define dxf_dbox_font    ((dbox_field) 6)

BOOL draw_dxf_setOptions (void)

{   dbox dialogue;
    BOOL readFile = FALSE, filling = TRUE;
    char buffer [dxf__maxBuffer];
    int n = 0;

    /*Create dialogue box*/
    if ((dialogue = dbox_new ("DXFloader")) == 0)
        return FALSE;

    /*Supply raw event handler for help messages*/
    dbox_raw_eventhandler (dialogue, &help_dboxrawevents, (void *) "DXF");

    /*We want the normal pointer for clicking on the dBox, so..*/
    visdelay_end ();

    /*Make sure options are up to date*/
    dbox_setnumeric (dialogue, dxf_dbox_milli,   dxf__millimetres);
    dbox_setnumeric (dialogue, dxf_dbox_inch,   !dxf__millimetres);
    dbox_setfield (dialogue,   dxf_dbox_info,   "");
    dbox_setfield (dialogue,   dxf_dbox_font,   dxf__standardFont);
    draw_setfield (dialogue,   dxf_dbox_unit,   dxf__baseUnit);

    dbox_show (dialogue);

    /*Respond to dialogue box actions*/
    while (filling)
    {   wimp_i i;

        switch (i = dbox_fillin (dialogue))
        {   case dxf_dbox_Abandon:
            case dbox_CLOSE:
                readFile = FALSE; filling = FALSE;
            break;

            case dxf_dbox_milli: case dxf_dbox_inch:
                dxf__millimetres = i == dxf_dbox_milli;
                dbox_setnumeric (dialogue, dxf_dbox_milli, dxf__millimetres);
                dbox_setnumeric (dialogue, dxf_dbox_inch, !dxf__millimetres);
            break;

            /*Major case - return or OK click*/
            case dxf_dbox_OK:
                /*Fetch the parameters - flags and font name first*/
                dbox_getfield (dialogue, dxf_dbox_font, dxf__standardFont,
                        dxf__maxBuffer);

                /*Load and verify numeric field*/
                dbox_getfield (dialogue, dxf_dbox_unit, buffer,
                        dxf__maxBuffer);
                ftracef1 ("buffer read from dbox contains \"%s\"\n",
                        buffer);
                if (sscanf (buffer, "%lf%n", &dxf__baseUnit, &n) < 1 ||
                        n != strlen (buffer))
                    dbox_setfield (dialogue, dxf_dbox_info,
                            msgs_lookup ("DxfU1"));
                else
                {  readFile = TRUE;
                   filling = FALSE;
                   dbox_setfield (dialogue, dxf_dbox_info,
                           msgs_lookup ("DxfL1"));
                }
                ftracef2 ("read numerical value of %f, %d chars\n",
                        dxf__baseUnit, n);
            break;
    }   }

    /*Discard the dialogue box*/
    dbox_dispose (&dialogue);

    return readFile;
}

/*
 Function    : dxf__loadfile
 Purpose     : load the given file into memory/open the file
 Parameters  : file name
               length
               OUT: file pointer
 Returns     : TRUE if loaded ok
 Description : loads the file and sets the file buffer pointers. Space for
               the buffer is allocated.
               If reading from disc, just open the file
               We also read the load options here. This must be done AFTER the
               file load so RAM xfer is happy: a bit silly because then cancel
               means we have wasted time.
*/

static BOOL dxf__loadfile (char *fileName, int length, FILE **filePointer)

{   DEBUG ("[2 ");

    if (dxf__viaRam)
    {   /*Allocate memory*/
        if (!FLEX_ALLOC ((flex_ptr) &dxf__fileBuffer, length))
        {   Error (0, "DxfM1");
            return FALSE;
        }

        /*Load in the file*/
        if (!draw_file_get (fileName, &dxf__fileBuffer, 0, &length,
                NULL))
        {   Error (0, "DxfL2");
            return FALSE;
        }

        /*Set globals*/
        dxf__fileLocation = 0;
        dxf__fileEnd = length;
        *filePointer = NULL;
    }
    else
    {   /*Open the file for read*/
        if ((*filePointer = fopen (fileName, "r")) == NULL)
        {   Error (0, "DxfF1");
            return FALSE;
        }
    }

    DEBUG (" 2]");
    return TRUE;
}

/*
 Function    : dxf__error, and variants
 Purpose     : report an error
 Parameters  : error string
 Returns     : void
 Description : output the error to a wimp error window
*/

static void dxf__error_low (char *format, char *message)

{   char buffer [256];
    sprintf (buffer, msgs_lookup (format), msgs_lookup (message),
            dxf__lineNumber);
    werr (FALSE, buffer);
}

static void dxf__error (char *message)

{   dxf__error_low ("Dxf00", message);
}

/*Specialised error reporting*/
static void dxf__error_room (char *message)

{ dxf__error_low ("Dxf01", message); }

static void dxf__error_group (char *message)

{ dxf__error_low ("Dxf02", message); }

static void dxf__error_endtab (char *message)

{ dxf__error_low ("Dxf03", message); }

/*
 Function    : dxf__getString
 Purpose     : fetch a line from the file
 Parameters  : output buffer pointer
               maximum length
 Returns     : FALSE at end
 Description : via file: read a line and lop the newline (and CR).
               via ram: read a line from the file block.
               Allows lines to be terminated with NL, CR, CRNL or CRNL
*/

static BOOL dxf__getString (char *to, int maxLength)

{   if (dxf__viaRam)
    {   int loaded = 0, ch = EOF;

      if (dxf__fileLocation >= dxf__fileEnd)
      {   dxf__error ("DxfO1");
        return FALSE;
      }

      /*Copy body of string*/
      while (loaded < maxLength && dxf__fileLocation < dxf__fileEnd)
      {   ch = to [loaded] = dxf__fileBuffer [dxf__fileLocation++];

        /*Exit on CR or newline*/
        if (ch == '\n' || ch == 0x0d)
          break;
        else loaded += 1;
      }
      to [loaded] = '\0';

      /*Skip further CR or newline, if any*/
      if (ch == 0x0d && dxf__fileBuffer [dxf__fileLocation] == '\n')
        dxf__fileLocation += 1;
      else if (ch == '\n' && dxf__fileBuffer [dxf__fileLocation] == 0x0d)
        dxf__fileLocation += 1;
    }
    else
    {   /*Similar loop for reading from file*/
        /*Can't use fgets because it terminates on \n only*/
        int loaded = 0, ch = EOF;

        while (loaded < maxLength && (ch = fgetc (state.file), ch != EOF))
        {   to [loaded] = ch;

          /*Exit on CR or newline*/
          if (ch == '\n' || ch == 0x0d)
            break;
          else loaded += 1;
        }
        to [loaded] = '\0';

        if (ch == EOF)
        {   dxf__error ("DxfF2");
            return FALSE;
        }

        /*Skip further CR or newline, if any*/
        if (ch == 0x0d)
        { ch = fgetc (state.file);
          if (ch != '\n') ungetc (ch, state.file);
        }
        else if (ch == '\n')
        { ch = fgetc (state.file);
          if (ch != 0x0d) ungetc (ch, state.file);
        }
    }

    dxf__lineNumber += 1;
    return TRUE;
}

/*
 Function    : dxf__set_to_file
 Purpose     : set input source to a given file
 Parameters  : filePointer (may be null for ram transfer)
 Returns     : void
 Description : the source for DXF groups is set to the given file
*/

static void dxf__set_to_file (FILE *filePointer)

{   state.file     = filePointer;
    state.fromfile = TRUE;
}

/*
 Function    : dxf__set_to_block
 Purpose     : set input source to a block
 Parameters  : block name (or NULL)
               pointer to block for saved state (or NULL)
 Returns     : TRUE if block found, else FALSE
 Description : the source for DXF groups is set to the given block structure.
*/

static BOOL dxf__set_to_block (char *blockName, dxf__state *saved)

{   DXF__block *block;
    for (block = dxf__blockHead; block; block = block->next)
    {   if (block->name != NULL)
        {   if (strcmp (block->name, blockName) == 0)
          {   /*Save state*/
              *saved = state;

              /*Set block source globals*/
              state.fromfile    = FALSE;
              state.block       = block;
              state.item        = block->items;
              state.pendingRead = FALSE;

              return TRUE;
          }
        }
    }

    /*Couldn't find block*/
    return FALSE;
}

/*
 Function    : dxf__restore_state
 Purpose     : restore saved input source
 Parameters  : saved block
 Returns     : void
 Description : restores the saved source
*/

static void dxf__restore_state (dxf__state *saved)

{   state = *saved;
}

/*
 Function    : dxf__readGroup
 Purpose     : read a group from the file
 Parameters  : void
 Returns     : group code, -1 on error
 Description : a group code and the following line are read. Depending on the
               value of the group, one of the three file reading globals
               (integer, floating point value, string) is set to the group
               value. The group type is left in a global as well as being
               returned.
               Group 999 objects are skipped (i.e. comments).
               Data may be read either from a file or from a list of block
               items -- in this case, a fiddled entry of 0,ENDBLK is returned.
*/

static int dxf__readGroup (void)

{   int groupCode;
    char buffer [dxf__maxBuffer];

    /*Check that we really need to read*/
    if (state.pendingRead)
    {   state.pendingRead = FALSE;
        return (state.group);
    }

    state.group = -1;
    do
    {   /*Read the group code and value until comments have been skipped*/
        if (state.fromfile)
        {   /*Get data from file*/
            if (!dxf__getString (buffer, dxf__maxBuffer)) return (-1);
            if (sscanf (buffer, "%d", &groupCode) < 1) groupCode = 0;
            state.group = groupCode;
            if (!dxf__getString (buffer, dxf__maxBuffer)) return (-1);

            /*Move group value to globals*/
            if (groupCode <= 9)
            {   int b;
                for (b = 0; buffer [b] == ' ' || buffer [b] == '\t'; b++);
                strcpy (state.groupString, buffer + b);
            }
            else if (groupCode < 60)
            {   if (sscanf (buffer, "%lf", &state.groupFloat) < 1)
                    state.groupFloat = 0;
            }
            else if (groupCode != 999)
            {   if (sscanf (buffer, "%d", &state.groupInt) < 1)
                    state.groupInt = 0;
            }
        }
        else
        {   /*Get data from block*/
            if (state.item == NULL)
            {   /*Fake end of block*/
                groupCode = 0;
                strcpy (state.groupString, "ENDBLK");
            }
            else
            {   groupCode = state.item->group;

                if (groupCode <= 9)
                    strcpy (state.groupString, state.item->data.s);
                else if (groupCode < 60)
                    state.groupFloat = state.item->data.f;
                else
                    state.groupInt = state.item->data.i;
                state.item = state.item->next;
            }
        }
    } while (groupCode == 999);

    /*Return group code*/
    state.group = groupCode;
    return (groupCode);
}


/*
 Function    : dxf__decodeByTable
 Purpose     : decode an object by a table search
 Parameters  : group value
               pointer to table
               OUT: extra data from table
 Returns     : action code
 Description : object decoder tables consist of a series of pairs of pointers
               to the argument value (a string) and an action code (integer).
               This routine seaches the table and returns the action code, or
               -1 if not found.
*/

static int dxf__decodeByTable (char *value, dxf__decoderTable *table,int *extra)

{   while (table->value)
    {   if (strcmp (table->value, value) == 0)
        {   *extra = table->extra;
            return (table->action);
        }
        else table++;
    }
    return (-1);
}

/*
 Function    : dxf__stringMatch
 Purpose     : check a group value string
 Parameters  : string to match against
 Returns     : TRUE on a match
 Description : does a simple string compare to check where we are in the file
*/

static BOOL dxf__stringMatch (char *value)

{   return (strcmp (state.groupString, value) == 0);
}

/*
 Function    : dxf__readString
 Purpose     : read a string group
 Parameters  : group type to match
               destination for string
               flag - TRUE if memory is to be allocated.
 Returns     : TRUE if read ok, and right group
 Description : attempts to read a string group of the given type.
               The string can contain control characters, marked by ^ followed
               by a character. (^, space means ^). These are left untouched.
*/

static BOOL dxf__readString (int match, char **to, BOOL allocate)

{   int group = dxf__readGroup ();

    if (group == match)
    {   /*Allocate space if necessary*/
        if (allocate)
            if ((int) (*to = heap_alloc (strlen (state.groupString)+1)) <= 0)
            {   dxf__error_room ("DxfZ5");
                *to = 0;
                return FALSE;
            }

        /*Copy string*/
        strcpy (*to, state.groupString);
        return TRUE;
    }

    if (group != -1) dxf__error ("DxfG1");
    return FALSE;   /*read error or wrong group type*/
}

/*
 Function    : dxf__readFloat
 Purpose     : read a floating point group
 Parameters  : group type to match
               destination for value
 Returns     : TRUE if read ok, and right group
 Description : attempts to read a floating point group of the given type
*/

static BOOL dxf__readFloat (int match, double *to)

{   int group = dxf__readGroup ();

    if (group == match)
    {   /*Copy value*/
        *to = state.groupFloat;
        return TRUE;
    }

    if (group != -1) dxf__error ("DxfG2");
    return FALSE;   /*read error or wrong group type*/
}

/*
 Function    : dxf__readInt
 Purpose     : read an integer group
 Parameters  : group type to match
               destination for value
 Returns     : TRUE if read ok, and right group
 Description : attempts to read an integer group of the given type
*/

static BOOL dxf__readInt (int match, int *to)

{   int group = dxf__readGroup ();

    if (group == match)
    {   /*Copy value*/
        *to = state.groupInt;
        return TRUE;
    }

    if (group != -1) dxf__error ("DxfG3");
    return FALSE;   /*read error or wrong group type*/
}

/*
 Function    : dxf__readCoord
 Purpose     : read a coordinate group
 Parameters  : group type to match
               destination for value
 Returns     : TRUE if read ok, and right group
 Description : attempts to read a coordinate group of the given type. This
               consists of an entry of the type and one of the type+10
*/

static BOOL dxf__readCoord (int match, dxf__coord *to)

{   double x;
    int group = dxf__readGroup ();

    /*Get group from file*/
    if (group == match)
    {   x = state.groupFloat;
        if ((group = dxf__readGroup ()) == match+10)
        {   to->x = x;
            to->y = state.groupFloat;
            return TRUE;
        }
        else if (group != -1)
            dxf__error ("DxfY1");
    }

    if (group != -1) dxf__error ("DxfG4");
    return FALSE;   /*read error or wrong group type*/
}


/*
 Function    : dxf__getPoint
 Purpose     : read a point when x has already been read
 Parameters  : group to match
               pointer to point structure
 Returns     : TRUE if successful
 Description : this is called just after reading the x part, when the group is
               a coordinate - it loads the point from the parameter
               already read, and the next one in the file
*/

static BOOL dxf__getPoint (int group, dxf__coord *point)

{   if (group != state.group)
    {   dxf__error ("DxfG5");
        return FALSE;
    }
    point->x = state.groupFloat;

    if (dxf__readGroup () != group+10)
    {   dxf__error ("DxfY2");
        return FALSE;
    }
    else
        point->y = state.groupFloat;

    return TRUE;
}


/*
 Function    : dxf__colour
 Purpose     : choose colour value from a DXF colour
 Parameters  : DXF colour
 Returns     : true colour value (BBGGRRxx)
 Description : the DXF colours are assumed to be:
  0 - white
  1 - red, 2 - yellow, 3 - green, 4 - cyan, 5 - blue, 6 - magenta, 7 - black
  0 is also treated as black

  Any other values are translated to black.
*/

/*Map colour number to BBGGRRxx value*/
static draw_coltyp dxf__colourTable [] =
{ 0xffffff00, /*white*/
  0x0000ff00, /*red*/
  0x00ffff00, /*yellow*/
  0x00ff0000, /*green*/
  0xffff0000, /*cyan*/
  0xff000000, /*blue*/
  0xff00ff00, /*magenta*/
  0x00000000  /*black*/
};

static draw_coltyp dxf__colour (int colour)

{   return ((colour < 0 || colour > 7) ? BLACK : dxf__colourTable [colour]);
}

/*
 Function    : dxf__setLineStyle
 Purpose     : set line drawing style parameters
 Parameters  : line thickness (DXF coordinates)
               current scale factor (x)
               colour
               flag: set fill colour as well as outline colour
               flag: set join style etc. to default
 Returns     : void
 Description : the parameters are set for the line which is currently being
               drawn. Line type could be added in here.
*/

static void dxf__setLineStyle (double thickness, double scale,
                              int colour,BOOL fill,BOOL join)

{   draw_pathwidth linewidth  = (int) (thickness * scale);
    draw_coltyp fillcolour;
    draw_coltyp linecolour = BLACK;

    linecolour = dxf__colour (colour);
    if (linewidth <= 0) linewidth = THIN;
    fillcolour = fill? linecolour: TRANSPARENT;

    draw_obj_setpath_colours (dxf__diag, fillcolour, linecolour, linewidth);
    if (join)
        draw_obj_setpath_style
              (dxf__diag, join_mitred, cap_butt, cap_butt, wind_evenodd,0,0);
}

/*
 Function    : dxf__convertAngle
 Purpose     : convert angles to anticlockwise
 Parameters  : angle in degrees
 Returns     : converted angle
 Description : add base and reduce to 0-360. If angdir is clockwise, subtract
               this from 360.
*/

static double dxf__convertAngle (double angle)

{   angle += dxf__varFloat.s.angbase;
    while (angle < 0)   angle += 360;
    while (angle > 360) angle -= 360;
    return ((dxf__varInt.s.angdir == 1) ? 360 - angle : angle);
}

/****************************************************************************
  Block level file reading routines.
 ****************************************************************************/

/*Data type array for "no parameters"*/
static int dxf__nullParam [] = {-1};

/*
 Function    : dxf__readGeneralBlock
 Purpose     : read a block of parameters, in any order
 Parameters  : {array of group types, output array} * 4
 Returns     : FALSE on any read error; next group has been read
 Description : this reads a whole block of parameters, which may be given in
               any order, and some of which may be omitted. For each of the
               four possible types of parameters (int, float, coord, string)
               the routine is given a list of the types of item it is to
               expect, and a space to put the results. For strings, the
               space consists of an array of pointers to strings which
               must have already been allocated.
               The types array is just an array of integers, containing the
               group codes we will expect to find. For coordinates, the value
               is the group code of the x coordinate.
               If a type occurs more than once in the data block, then all but
               the last occurrence is discarded. All types arrays must be
               passed, even if there are no objects of that type (in this case,
               the values array may be NULL, however).
               The routine exits when it finds a group type that does not match
               any of the ones specified. The type and the value of the
               parameter are left in the common globals.
               All type arrays must have a -1 entry to terminate them.
*/

static int dxf__readGeneralBlock
   (int *intType,    int *intVal,
    int *floatType,  double *floatVal,
    int *coordType,  dxf__coord *coordVal,
    int *stringType, char **stringVal)

{   int group;
    int *table;
    int index;

    do
    {   /*Get a group*/
        group = dxf__readGroup ();
        if (group == -1)
        {   state.pendingRead = TRUE;
            return FALSE;
        }

        /*Search for group type in the relevant table*/
        table = (group < 10) ? stringType :
                (group < 30) ? coordType  :
                (group < 60) ? floatType  :
                intType;
        for (index = 0; table [index] != -1 && table [index] != group; index++);

        /*-1 -> not found: return*/
        if (table [index] == -1)
        {   state.pendingRead = TRUE;
            return TRUE;
        }

        /*Record value*/
        if (group < 10)
            strcpy (stringVal [index], state.groupString);
        else if (group < 30)
        {   if (!dxf__getPoint (group, coordVal+index))
            {   state.pendingRead = TRUE;
                return FALSE;
            }
        }
        else if (group < 60)
            floatVal [index] = state.groupFloat;
        else
            intVal [index] = state.groupInt;
    } while (TRUE);

    return TRUE; /*This never happens - just here to fool compiler*/
}

/*Data blocks for get common*/
static int dxf__commonInt []    = {62 /*colour number*/, -1};
static int dxf__commonFloat []  = {38 /*elevation*/, 39 /*thickness*/, -1};
static int dxf__commonString [] = {6 /*line type name*/,
                                   8 /*layer name*/, -1};

/*
 Function    : dxf__getCommon
 Purpose     : get parameters common between entities, and first group
 Parameters  : OUT: index into line type table
               OUT: line thickness
               OUT: colour number
 Returns     : code of first group in entity; -1 on error; -2 for invisible
 Description : the common parameters are read for the current entity. If they
               are not given, they are set to default values for the layer.
               If the layer is not defined, system defaults are used instead.
               On exit, the first group of the remainder of the entity has just
               been read.
               The default thickness is 0, except for polylines, where it
               comes from a global. To allow for this, we pass back -1 as the
               default, and let the entity handler sort it out.
               An object is invisible if either its colour is negative, or it
               is in a layer with a negative colour. In this case, the code
               -2 is returned, so the rest of the object can be ignored.
*/

static int dxf__getCommon (int *linetype, double *thickness, int *colour)

{   int index;

    /*Internal locations for parameters*/
    char *stringVars [2];
    double floatVars [2];
    int col;
    char layerName [dxf__maxBuffer];
    char linetypeName [dxf__maxBuffer];
    int ltype;
    dxf__layerStruct *layer;

    stringVars [0] = linetypeName; stringVars [1] = layerName;

    /*Set up default parameters*/
    strcpy (linetypeName, "BYLAYER");
    col = DXF__BYLAYER;
    floatVars [0] = 0; /*elevation*/
    floatVars [1] = 0;  /*thickness*/

    /*Read common block*/
    if (!dxf__readGeneralBlock (dxf__commonInt,    &col,
                               dxf__commonFloat,  floatVars,
                               dxf__nullParam,    NULL,
                               dxf__commonString, stringVars))
    {   return FALSE;
    }

    /*Convert layer name to a pointer*/
    for (layer = dxf__layers; layer != NULL && layer->name != NULL; layer++)
        if (strcmp (layerName, layer->name) == 0) break;

    /*If layer name is missing, try using default one*/
    if (layer && layer->name == NULL)
    {   for (layer = dxf__layers; layer->name != NULL; layer++)
            if (strcmp (dxf__varString.s.clayer, layer->name) == 0)
                break;
        /*If layer name not found, system parameters get used*/
    }

    /*Set defaults from layer parameters*/
    ltype = (layer) ? layer->lineType : -1;

    /*Check parameters*/
    if (strcmp (linetypeName, "BYBLOCK") == 0)
        ltype = dxf__varInt.s.blocklineType;
    else if (strcmp (linetypeName, "BYLAYER") != 0)
    {   /*Search for line type in table*/
        if (dxf__lineTypes)
        {   for (index = 0; dxf__lineTypes [index]; index++)
              if (strcmp (linetypeName, dxf__lineTypes [index]) == 0)
                  break;
          if (dxf__lineTypes [index])
              ltype = index;
        }
        /*If not found, leave as layer value (or 0)*/
    }

    if (col == DXF__BYBLOCK)
        col = dxf__varInt.s.blockcolour;
    else if (state.groupInt == DXF__BYLAYER)
        col = layer->colour;

    *linetype  = ltype;
    *thickness = floatVars [1];
    *colour    = col;

    /*Return next group code*/
    return ((col < 0 || (layer && layer->colour < 0)) ? -2 : state.group);
}

/*Macro for doing work of get common. Assumes the existence of
   variables, linetype, thickness, colour, group and takes the
   error message on a bad read as the parameter.
*/
#define Dxf_getCommon \
  { if ((group = dxf__getCommon (&linetype, &thickness, &colour)) == -1) \
      return FALSE; \
  }

/*Macro for giving up on an invisible object. This must be called after the
   remaining parameters have been read.
*/
#define Dxf_skipIfInvisible {if (group == -2) return TRUE;}

/*****************************************************************************
  Level 4 file reading: individual entity types.
  Each entity type has associated with it one or more tables, giving the
  object types it expects to get.
 *****************************************************************************/

/*Data tables for LINE entity*/
static int dxf__lineCoord []  = {10, 11, -1};

/*
 Function    : dxf__renderLine
 Purpose     : render a LINE entity
 Parameters  : context
 Returns     : TRUE on success
 Description : constructs a line between the given points
 Approximations: line type not used
*/

static BOOL dxf__renderLine (dxf__context *c)

{   int group;
    int linetype;
    double thickness;
    int colour;
    dxf__coord point [2];

    DEBUG (" [line ");
    /*Get common parameters*/
    Dxf_getCommon;

    DEBUG ("dxf__readGeneralBlock| ");
    /*Get remaining parameters*/
    if (!dxf__readGeneralBlock (dxf__nullParam, NULL,
                               dxf__nullParam, NULL,
                               dxf__lineCoord, point,
                               dxf__nullParam, NULL))
    {   return FALSE;
    }

    DEBUG ("skip invisible| ");
    Dxf_skipIfInvisible;

    /*Construct line*/
    DEBUG ("draw_obj_checkspace| ");
    if (draw_obj_checkspace (dxf__diag, sizeof (draw_pathstr)
                                       + sizeof (drawmod_path_movestr)
                                       + sizeof (drawmod_path_linetostr)
                                       + sizeof (drawmod_path_termstr)))
    {   dxf__error_room ("DxfZ6");
        return FALSE; /*Not enough space*/
    }

    DEBUG ("draw_obj_start| ");
    draw_obj_start (dxf__diag, draw_OBJPATH);
    #if TRACE
    { int hdroff = *(int *) (dxf__diag->paper + dxf__diag->misc->stacklimit);
      draw_objptr hdrptr;
      hdrptr.bytep = dxf__diag->paper + hdroff;
      ftracef4 ("dxf__renderLine: stack is at offset %d, "
          "top object is 0x%X (offset %d) size %d\n",
          dxf__diag->misc->stacklimit, hdrptr.bytep, hdrptr.bytep - dxf__diag->paper, hdrptr.objhdrp->size);
    }
    #endif

    DEBUG ("dxf__setLineStyle| ");
    dxf__setLineStyle (thickness, DXFtoDraw, colour, FALSE, TRUE);
    #if TRACE
    { int hdroff = *(int *) (dxf__diag->paper + dxf__diag->misc->stacklimit);
      draw_objptr hdrptr;
      hdrptr.bytep = dxf__diag->paper + hdroff;
      ftracef3 ("dxf__renderLine: stack is at offset %d, "
          "top object is %d size %d\n",
          dxf__diag->misc->stacklimit, hdrptr.bytep - dxf__diag->paper, hdrptr.objhdrp->size);
    }
    #endif

    DEBUG ("draw_obj_addpath_move| ");
    #if TRACE
    { int hdroff = *(int *) (dxf__diag->paper + dxf__diag->misc->stacklimit);
      draw_objptr hdrptr;
      hdrptr.bytep = dxf__diag->paper + hdroff;
      ftracef3 ("dxf__renderLine: stack is at offset %d, "
          "top object is %d size %d\n",
          dxf__diag->misc->stacklimit, hdrptr.bytep - dxf__diag->paper, hdrptr.objhdrp->size);
    }
    #endif

    draw_obj_addpath_move (dxf__diag, dxf__cvt (&point [0], c));
    DEBUG ("draw_obj_addpath_line| ");
    draw_obj_addpath_line (dxf__diag, dxf__cvt (&point [1], c));
    DEBUG ("draw_obj_addpath_term| ");
    draw_obj_addpath_term (dxf__diag);
    DEBUG ("draw_obj_complete ");
    draw_obj_complete (dxf__diag);

    DEBUG (" line]");
    return TRUE;
}

/*
 Function    : dxf__renderPoint
 Purpose     : render a point entity
 Parameters  : context
 Returns     : TRUE on success
 Description : discard the point
*/

static BOOL dxf__renderPoint (dxf__context *c)

{   int group;
    int linetype;
    double thickness;
    int colour;
    dxf__coord point;

    DEBUG (" [point ");
    /*Get common parameters*/
    Dxf_getCommon;

    /*Get point location*/
    if (!dxf__readCoord (group, &point)) return FALSE;

    c = c;

    DEBUG (" point]");
    return TRUE;
}

/*Data tables for TRACE/SOLID entity*/
static int dxf__traceCoord []  = {10, 11, 12, 13, -1};

/*
 Function    : dxf__renderTrace
 Purpose     : render a TRACE or SOLID entity
 Parameters  : context
               flag: set to fill shape
 Returns     : TRUE on success
 Description : up to 4 points are read. If the fourth point is the same as the
               third, it is discarded.
 Approximations: line type not used
*/

static BOOL dxf__renderTrace (dxf__context *c, BOOL fill)

{   int group;
    int linetype;
    double thickness;
    int colour;
    dxf__coord point [4];               /*Points*/
    int p;                          /*Point counter*/
    int i;

    DEBUG (" [trace ");
    /*Get common parameters*/
    Dxf_getCommon;

    /*Get point parameters*/
    if (!dxf__readGeneralBlock (dxf__nullParam, NULL,
                               dxf__nullParam, NULL,
                               dxf__traceCoord, point,
                               dxf__nullParam, NULL))
    {   return FALSE;
    }

    Dxf_skipIfInvisible;

    /*Discard 4th point if same as third*/
    p = (point [2].x == point [3].x && point [2].y == point [3].y) ? 3 : 4;

    /*Construct trace/solid*/
    if (draw_obj_checkspace (dxf__diag, sizeof (draw_pathstr)
                                       + sizeof (drawmod_path_linetostr) * (p+1)
                                       + sizeof (drawmod_path_termstr)))
    {   dxf__error_room ("DxfZ8");
        return FALSE; /*Not enough space*/
    }

    draw_obj_start (dxf__diag, draw_OBJPATH);
    dxf__setLineStyle (thickness, DXFtoDraw, colour, fill, TRUE);
    draw_obj_addpath_move (dxf__diag, dxf__cvt (&point [0], c));
    for (i = 1; i <= p; i++)
        draw_obj_addpath_line (dxf__diag, dxf__cvt (&point [i], c));

    /*Close back to first point*/
    draw_obj_addpath_line (dxf__diag, dxf__cvt (&point [0], c));
    draw_obj_addpath_close (dxf__diag);
    draw_obj_addpath_term (dxf__diag);
    draw_obj_complete (dxf__diag);

    DEBUG (" trace]");
    return TRUE;
}

/*Data tables for TEXT entity*/
static int dxf__textInt []    = {71 /*text generation flags*/,
                                 72 /*justification type*/, -1};
static int dxf__textFloat []  = {40 /*height*/, 41 /*rel. X scale factor*/,
                                 50 /*rotation angle*/,
                                 51 /*obliquing angle*/,-1};
static int dxf__textCoord []  = {10 /*insertion point*/,
                                 11 /*alignment point*/, -1};
static int dxf__textString [] = {1 /*text*/, 7 /*text style name*/, -1};

/*
 Function    : dxf__renderText
 Purpose     : render a TEXT entity
 Parameters  : context
 Returns     : TRUE on success
 Description : a text object is created, with the specified text size.
               The exact point at which the text is plotted depends on the
               justification type. (See approximations).
 Approximations: rotation and obliquing angles ignored;
                 text style name ignored;
                 text generation flags ignored [backwards/upside down].
                 For text justification, we assume that the total size of the
                 string is given by the x font size times the number of
                 characters horizontally, and the y font size vertically.
                 Clearly, this will be inaccurate for proportionally spaced
                 fonts. The alternative is just to assume that the text
                 bounding box will always be exact, but in this case, we might
                 as well not be justifying the text at all (we could then just
                 plot at the left hand point).
*/

static BOOL dxf__renderText (dxf__context *c)

{   int group, linetype, colour, fontindx;
    double thickness, rawsizex, rawsizey;

    /*Text parameters*/
    int intVars [2];
    double floatVars [4];
    dxf__coord point [2];
    char text [1000], styleName [dxf__maxBuffer], *stringVars [2];

    DEBUG (" [text ");
    /*Get common parameters*/
    floatVars [1] = 1.0; floatVars [2] = 0.0; floatVars [3] = 0.0;
    strcpy (styleName, "STANDARD");
    intVars [0] = 0; intVars [1] = 0;
    Dxf_getCommon;

    /*Get additional parameters*/
    stringVars [0] = text; stringVars [1] = styleName;
    if (!dxf__readGeneralBlock (dxf__textInt,    intVars,
                               dxf__textFloat,  floatVars,
                               dxf__textCoord,  point,
                               dxf__textString, stringVars))
    {   return FALSE;
    }

    Dxf_skipIfInvisible;

#ifdef SYSTEMFONT
    /*Plot everything in system font*/
    fontindx = 0; /*System font*/
#else
    fontindx = dxf__standardFontNumber;
#endif
    rawsizex = floatVars [0] * floatVars [1];
    rawsizey = floatVars [0];
    if (rawsizex < 0) rawsizex = -rawsizex;
    if (rawsizey < 0) rawsizey = -rawsizey;

    /*Adjust position for alignment point*/
    switch (intVars [1])
    {   case 0:                      /*Left justified*/
        break;
        case 1:                      /*Centred along baseline*/
          point [0].x = (point [0].x + point [1].x - rawsizex*strlen (text)) /2;
          point [0].y -= rawsizey/2;  break;
        break;
        case 2:                      /*Right justified*/
          point [0].x = point [1].x - rawsizex * strlen (text);
          point [0].y = point [1].y;
        break;
        case 3:                      /*Vertical centering in bounding box*/
          point [0].y = (point [0].y + point [1].y - rawsizey) / 2;
          break;
        case 4:                      /*Full centering in bounding box*/
          point [0].y = (point [0].y + point [1].y - rawsizey) / 2;
        /*Fall into case 5*/
        case 5:                      /*Horizontal centering in bounding box*/
          point [0].x = (point [0].x + point [1].x - rawsizex*strlen (text)) / 2;
        break;
    }

    /*Check space for object*/
    if (draw_obj_checkspace (dxf__diag, sizeof (draw_textstr)+strlen (text)))
    {   dxf__error_room ("DxfZ9");
        return FALSE; /*Not enough space*/
    }

    /*Start text object*/
    draw_obj_start (dxf__diag, draw_OBJTEXT);
    draw_obj_setcoord (dxf__diag, dxf__cvt (&point [0], c));
    draw_obj_settext_font (dxf__diag, fontindx,
                          dxf__draw (rawsizex), dxf__draw (rawsizey));
    draw_obj_settext_colour (dxf__diag, dxf__colour (colour), WHITE);
    draw_obj_addstring (dxf__diag, text);
    draw_obj_complete (dxf__diag);
    DEBUG (" text]");
    return TRUE;
}

/*Data tables for POLYLINE entity*/
static int dxf__polylineInt []    = {66 /*vertices follow*/, 70 /*flags*/,
                                     -1};
static int dxf__polylineFloat []  = {40 /*start width*/, 41 /*end width*/,
                                     -1};

/*Data tables for VERTEX entity*/
static int dxf__vertexInt []    = {70 /*vertex flags*/, -1};
static int dxf__vertexFloat []  = {40 /*start width*/, 41 /*end width*/,
                                   42 /*bulge*/,
                                   50 /*curve fit tangent direction*/, -1};
static int dxf__vertexCoord []  = {10 /*location*/, -1};

/*
 Function    : dxf__renderPolyline
 Purpose     : render a POLYLINE entity
 Parameters  : context
 Returns     : TRUE on success
 Description :
 Approximations: end widths ignored;
                 no curve fitting - just simple line segments;
                 line type not used;
                 the attributes of each segment (colour, width, ...) are
                 ignored - the overall attributes are used for all of them.
                 (Draw only allows one set of attributes for the whole path).
                 the polyline width is the highest of the following specified:
                   polyline start width;
                   entity line thickness;
                   $plinewid.
*/

static BOOL dxf__renderPolyline (dxf__context *c)

{   int group;
    int linetype;
    double thickness;
    int colour;
    dxf__coord firstPoint;
    BOOL seenFirst = FALSE;
    BOOL invisible;                  /*set if whole line is invisible*/

    /*Polyline parameters*/
    int polylineInt [2];
    double polylineFloat [2];           /*start and end widths*/

    /*Vertex parameters*/
    int vertexInt [1];
    double vertexFloat [4];
    dxf__coord point;

    DEBUG (" [polyline ");
    /*Get common parameters*/
    Dxf_getCommon;
    invisible = (group == -2);

    /*Get polyline parameters*/
    polylineInt [1] = 0;                            /*Default flags*/
    polylineFloat [0] = (thickness == -1) ? dxf__varFloat.s.plinewid :thickness;
    if (!dxf__readGeneralBlock (dxf__polylineInt, polylineInt,
                               dxf__polylineFloat, polylineFloat,
                               dxf__nullParam, NULL,
                               dxf__nullParam, NULL))
    {   return FALSE;
    }

    /*Check we had a 'vertices follow' flag*/
    if (polylineInt [0] != 1)
    {   dxf__error ("DxfP1");
        return FALSE;
    }

    /*Check space for raw object*/
    if (draw_obj_checkspace (dxf__diag, sizeof (draw_pathstr)
                                   + sizeof (drawmod_path_termstr)))
    {   dxf__error_room ("DxfZA");
        return FALSE; /*Not enough space*/
    }

    /*Start object - set standard parameters, and change join styles*/
    draw_obj_start (dxf__diag, draw_OBJPATH);
    dxf__setLineStyle (polylineFloat [0], DXFtoDraw, colour, FALSE, TRUE);

    /*Get vertices until SEQEND*/
    while ((group = dxf__readGroup ()) == 0)
    {   if (!dxf__stringMatch ("VERTEX")) break;

        /*Get vertex common data (and discard)*/
        vertexFloat [0] = polylineFloat [0];
        vertexFloat [1] = polylineFloat [1];
        vertexFloat [3] = 0.0;
        Dxf_getCommon;

        /*Get vertex parameters (and discard)*/
        if (!dxf__readGeneralBlock (dxf__vertexInt,   vertexInt,
                                   dxf__vertexFloat, vertexFloat,
                                   dxf__vertexCoord, &point,
                                   dxf__nullParam,   NULL))
        {   return FALSE;
        }

        /*Plot vertex if line as a whole is not invisible*/
        if (!invisible)
        {   /*Check space for next vertex*/
            if (draw_obj_checkspace (dxf__diag, sizeof (drawmod_path_linetostr)))
            {   dxf__error_room ("DxfZB");
                return FALSE; /*Not enough space*/
            }

            if (!seenFirst)
            {   /*First point - save it and use a move*/
                firstPoint = point;
                seenFirst = TRUE;
                draw_obj_addpath_move (dxf__diag, dxf__cvt (&point, c));
            }
            else if (group == -2)
            {   /*Segment is invisible: replace by a move*/
                draw_obj_addpath_move (dxf__diag, dxf__cvt (&point, c));
            }
            else
            {   /*Add line*/
                draw_obj_addpath_line (dxf__diag, dxf__cvt (&point, c));
            }
        }
    }

    /*Close object if required*/
    if (polylineInt [1] & 1)
    {   if (draw_obj_checkspace (dxf__diag, 2*sizeof (drawmod_path_linetostr)))
        {   dxf__error_room ("DxfZB");
            return FALSE; /*Not enough space*/
        }

        /*Add to object*/
        draw_obj_addpath_line (dxf__diag, dxf__cvt (&firstPoint, c));

        /*Close the path*/
        draw_obj_addpath_close (dxf__diag);
    }

    /*End object*/
    draw_obj_addpath_term (dxf__diag);
    draw_obj_complete (dxf__diag);

    /*Error checks*/
    if (group > 0)
    {   dxf__error ("DxfG6");
        return FALSE;
    }
    else if (group < 0)
        return FALSE;
    else if (!dxf__stringMatch ("SEQEND"))
    {   dxf__error ("DxfP2");
        return FALSE;
    }

    DEBUG (" polyline]");
    return TRUE;
}

/*Data tables for ARC entity*/
static int dxf__arcFloat []  = {40 /*radius*/,
                                50 /*start angle*/, 51 /*end angle*/, -1};
static int dxf__arcCoord []  = {10 /*centre*/, -1};

/*Macro for degrees to radians conversion*/
#define dxf_deg_to_rad(degrees) (degrees*bezierarc_pi/180)

/*
 Function    : dxf__renderArc
 Purpose     : render an ARC entity
 Parameters  : context
 Returns     : TRUE on success
 Description : draw an arc object, split into a number of section, each of at
               most 90 degrees.
 Approximations: line type is not used.
*/

static BOOL dxf__renderArc (dxf__context *c)

{   int group;
    int linetype, colour, a;
    double thickness;

    /*Arc parameters*/
    dxf__coord centre;
    double arcFloat [3];
    double angle [2]; /*0 = start, 1 = end*/
    int radius;
    bezierarc_coord dcentre;

    /*Arc drawing variables*/
    draw_objcoord start, end, bezier1, bezier2;
    int segments, segnum;

    DEBUG (" [arc ");
    /*Get common parameters*/
    Dxf_getCommon;

    /*Get arc parameters*/
    if (!dxf__readGeneralBlock (dxf__nullParam, NULL,
                               dxf__arcFloat,  arcFloat,
                               dxf__arcCoord,  &centre,
                               dxf__nullParam, NULL))
    {   return FALSE;
    }

    Dxf_skipIfInvisible;

    /*Get parameters into right form*/
    dcentre.x  = dxf__cvtX (centre.x, c);
    dcentre.y  = dxf__cvtY (centre.y, c);
    radius     = dxf__draw (arcFloat [0]);
    for (a = 0; a < 2; a++)
    {   /*Reduce angle to 0...360*/
      angle [a]      = dxf__convertAngle (arcFloat [a+1]);

      /*Convert to radians*/
      angle [a] = dxf_deg_to_rad (angle [a]);
    }

    /*Don't do anything for arcs with no radius. JRC*/
    if (radius > 0.0)
    { /*Reverse angles to get right (anticlockwise) order*/
      if (dxf__varInt.s.angdir == 1)
      {   double temp;
          temp     = angle [0];
          angle [0] = angle [1];
          angle [1] = temp;
      }

      /*Start arc and reserve space*/
      segments = bezierarc_start ((bezierarc_coord)dcentre, angle [0], angle [1],
                   radius,
                   (bezierarc_coord *)&start,   (bezierarc_coord *)&end,
                   (bezierarc_coord *)&bezier1, (bezierarc_coord *)&bezier2);

      if (draw_obj_checkspace (dxf__diag, sizeof (draw_pathstr)
                                      + sizeof (drawmod_path_bezierstr) * segments
                                      + sizeof (drawmod_path_termstr)))
      {   dxf__error_room ("DxfZC");
          return FALSE;
      }

      /*Start the path*/
      draw_obj_start (dxf__diag, draw_OBJPATH);
      dxf__setLineStyle (thickness, DXFtoDraw, colour, FALSE, TRUE);

      /*Move to start*/
      draw_obj_addpath_move (dxf__diag, &start);

      segnum = 1;
      do
      {   draw_obj_addpath_curve (dxf__diag, &bezier1, &bezier2, &end);

          segnum = bezierarc_segment (segnum, (bezierarc_coord *)&end,
                    (bezierarc_coord *)&bezier1, (bezierarc_coord *)&bezier2);
      } while (segnum);

      /*End the path*/
      draw_obj_addpath_term (dxf__diag);
      draw_obj_complete (dxf__diag);
    }

    DEBUG (" arc]");
    return TRUE;
}

/*Data tables for CIRCLE entity*/
static int dxf__circleFloat []  = {40 /*radius*/, -1};
static int dxf__circleCoord []  = {10 /*centre*/, -1};

/*
 Function    : dxf__renderCircle
 Purpose     : render a CIRCLE entity
 Parameters  : context
 Returns     : TRUE on success
 Description : builds a circle from four arcs
 Approximations: line type not used.
*/

static BOOL dxf__renderCircle (dxf__context * c)

{   int group;
    int linetype;
    double thickness;
    int colour;

    /*Circle parameters*/
    dxf__coord centre;
    double radius;
    draw_objcoord dcentre;

    DEBUG (" [circle ");
    /*Get common parameters*/
    Dxf_getCommon;

    /*Get circle parameters*/
    if (!dxf__readGeneralBlock (dxf__nullParam,   NULL,
                               dxf__circleFloat, &radius,
                               dxf__circleCoord, &centre,
                               dxf__nullParam,   NULL))
    {   return FALSE;
    }

    Dxf_skipIfInvisible;

    if (draw_obj_checkspace (dxf__diag, sizeof (draw_pathstr)
                                       + sizeof (drawmod_path_bezierstr) * 4
                                       + sizeof (drawmod_path_closelinestr)
                                       + sizeof (drawmod_path_termstr)))
    {   dxf__error_room ("DxfZD");
        return FALSE; /*Not enough space*/
    }

    /*Start the object*/
    draw_obj_start (dxf__diag, draw_OBJPATH);
    dxf__setLineStyle (thickness, DXFtoDraw, colour, FALSE, TRUE);

    dcentre = *dxf__cvt (&centre, c);

    /*Draw circle*/
    draw_obj_addpath_centred_circle (dxf__diag, dcentre, dxf__draw (radius),
                                    FALSE);

    /*Finish the path*/
    draw_obj_addpath_term (dxf__diag);
    draw_obj_complete (dxf__diag);

    DEBUG (" circle]");
    return TRUE;
}

/*Data tables for INSERT entity*/
static int dxf__insertInt []    = {66 /*attributes flag*/,
                                   70 /*column count*/, 71 /*row count*/,
                                   -1};
static int dxf__insertFloat []  = {41 /*x scaling*/, 42 /*y scaling*/,
                                   43 /*z scaling*/, 44 /*column spacing*/,
                                   45 /*row spacing*/,
                                   50 /*rotation angle*/, -1};
static int dxf__insertCoord []  = {10 /*insert point*/, -1};
static int dxf__insertString [] = {2 /*block name*/, -1};

/*
 Function    : dxf__renderInsert
 Purpose     : render an INSERT entity
 Parameters  : context
 Returns     : TRUE on success
 Description : an insert refers to a block as defined in the blocks table. We
               must find it if we can, and set the defaults to the values
               specified for it. The previous defaults must be preserved.
               Once this has been set up, we then draw it into a group.
 Approximations: the column and row values, all attributes entries, rotation
                 and z scaling are ignored.
*/

static BOOL dxf__renderInsert (dxf__context *c)

{   dxf__context newcontext;
    int group, linetype, colour;
    double thickness;
    BOOL ok;
    int start_offset;

    /*Saved values*/
    int save_colour, save_linetype;
    double save_thickness;
    dxf__state saved;

    /*Insert parameters*/
    int intVars [3];
    double floatVars [6];
    dxf__coord insert;
    char *stringVars [1], blockName [dxf__maxBuffer];

    DEBUG (" [insert ");
    /*Get common parameters*/
    stringVars [0] = blockName;
    Dxf_getCommon;

    /*Get insert parameters*/
    intVars [0] = 0; intVars [1] = 1; intVars [2] = 1;
    floatVars [0] = 1.0; floatVars [1] = 1.0; floatVars [2] = 1.0;
    floatVars [3] = 0.0; floatVars [4] = 0.0; floatVars [5] = 0.0;
    if (!dxf__readGeneralBlock (dxf__insertInt,    intVars,
                               dxf__insertFloat,  floatVars,
                               dxf__insertCoord,  &insert,
                               dxf__insertString, stringVars))
    {   return FALSE;
    }

    Dxf_skipIfInvisible;

    /*Look for the block*/
    if (!dxf__set_to_block (blockName, &saved))
    {   dxf__error ("DxfI1");
        return FALSE;
    }

    /*Set defaults*/
    save_colour    = dxf__varInt.s.blockcolour;
    save_linetype  = dxf__varInt.s.blocklineType;
    save_thickness = dxf__varFloat.s.blockthickness;
    dxf__varInt.s.blockcolour      = colour;
    dxf__varInt.s.blocklineType    = linetype;
    dxf__varFloat.s.blockthickness = thickness;

    /*Start group*/
    if (draw_obj_checkspace (dxf__diag, sizeof (draw_groustr)))
    {   dxf__error_room ("DxfZE");
        return FALSE;
    }
    start_offset = dxf__diag->misc->ghostlimit;
    draw_obj_start (dxf__diag, draw_OBJGROUP);

    /*Render insert entities*/
    newcontext.base = state.block->base;
    ok = dxf__drawEntity ("ENDBLK", &newcontext);

    /*End group*/
    draw_obj_complete (dxf__diag);

    /*Transform the group to the right size and place*/
    dxf__transform (start_offset, dxf__diag->misc->ghostlimit,
                   dxf__cvtX (insert.x, c), dxf__cvtY (insert.y, c),
                   (dxf__coord *) (&floatVars [0]), FALSE);

    /*Reset defaults*/
    dxf__varInt.s.blockcolour      = save_colour;
    dxf__varInt.s.blocklineType    = save_linetype;
    dxf__varFloat.s.blockthickness = save_thickness;

    /*Reset state*/
    dxf__restore_state (&saved);
    DEBUG (" insert]");
    return (ok);
}

/*****************************************************************************
  Level 3 file reading:
   tables
   entities
 *****************************************************************************/

/*Data tables for line type table entries*/
/*There will actually be several type 49 entries, but they all get ignored*/
static int dxf__ltypeInt []    = {62 /*colour number or -1*/, 70 /*flags*/,
                                  72 /*alignment code*/,
                                  73 /*number if dash length items*/, -1};
static int dxf__ltypeFloat []  = {40 /*total pattern length*/,
                                  49 /*dash length*/-1};
static int dxf__ltypeString [] = {2 /*line type name*/, 3 /*description*/,
                                  -1};

/*
 Function    : dxf__readLtypeTable
 Purpose     : read line type table
 Parameters  : maximum size of table
 Returns     : TRUE if read OK
 Description : the line type name is read and logged. The remaining information
               refers to dashed lines, which we cannot handle, and so is
               skipped.
*/

static BOOL dxf__readLtypeTable (int maxSize)

{   int index = 0;
    int group;
    int intVars [4];
    double floatVars [2];
    char linetypeName [dxf__maxBuffer];
    char description [dxf__maxBuffer];
    char *stringVars [2];

    DEBUG (" [ltype ");
    if ((group = dxf__readGroup ()) != 0)
    {   if (group != -1) dxf__error_group ("DxfZ1");
        return FALSE;
    }

    /*Allocate space for line types*/
    if ((int) (dxf__lineTypes = heap_alloc (sizeof (char *) * (maxSize+1))) <= 0)
    {   dxf__error_room ("DxfZ1");
        dxf__lineTypes = 0;
        return FALSE;
    }
    dxf__lineTypes [index] = NULL;        /*Safety termination of table*/

    /*Set up indexes for reading*/
    stringVars [0] = linetypeName;
    stringVars [1] = description;

    /*Read line type data*/
    while (dxf__stringMatch ("LTYPE"))
    {   /*Read line type parameters*/
        if (!dxf__readGeneralBlock (dxf__ltypeInt,    intVars,
                                   dxf__ltypeFloat,  floatVars,
                                   dxf__nullParam,   NULL,
                                   dxf__ltypeString, stringVars))
        {   return FALSE;
        }

        if ((int) (dxf__lineTypes [index] = heap_alloc (strlen (linetypeName)+1))
                 <= 0)
        {   dxf__error_room ("DxfZF");
            dxf__lineTypes [index] = 0;
            return FALSE;
        }

        strcpy (dxf__lineTypes [index++], linetypeName);
        dxf__lineTypes [index] = NULL;        /*Safety termination of table*/

        /*Skip to next 0 group*/
        while ((group = dxf__readGroup ()) > 0);
        if (group == -1) return FALSE;
    }

    DEBUG (" ltype]");
    if (dxf__stringMatch ("ENDTAB"))
        return TRUE;
    else
    {   dxf__error_endtab ("DxfZ1");
        return FALSE;
    }
}

/*Data tables for layer table entries*/
static int dxf__layerInt []    = {62 /*colour number or -1*/, 70 /*flags*/,
                                  -1};
static int dxf__layerString [] = {2 /*layer name*/, 6 /*linetype name*/,
                                  -1};

/*
 Function    : dxf__readLayerTable
 Purpose     : read layer table
 Parameters  : maximum size of table
 Returns     : TRUE if read OK
 Description : for each layer, we record the layer name, colour and line type
               name.
*/

static BOOL dxf__readLayerTable (int maxSize)

{   dxf__layerStruct *layer;
    char layerName [dxf__maxBuffer], linetypeName [dxf__maxBuffer];
    char *stringVars [2];
    int intVars [2];
    int index, group;

    DEBUG (" [layer ");
    if ((group = dxf__readGroup ()) != 0)
    {   if (group != -1) dxf__error_group ("DxfZ2");
        return FALSE;
    }

    /*Allocate space for table*/
    if ((int) (dxf__layers = heap_alloc (sizeof (dxf__layerStruct) * (maxSize+1)))
              <= 0)
    {   dxf__error_room ("DxfZ2");
        dxf__layers = 0;
        return FALSE;
    }
    layer = dxf__layers;

    /*Set up indexes for reading*/
    stringVars [0] = layerName;
    stringVars [1] = linetypeName;

    /*Read layer data*/
    while (dxf__stringMatch ("LAYER"))
    {   /*Read layer parameters*/
        if (!dxf__readGeneralBlock (dxf__layerInt,    intVars,
                                   dxf__nullParam,   NULL,
                                   dxf__nullParam,   NULL,
                                   dxf__layerString, stringVars))
        {   return FALSE;
        }

        if ((int) (layer->name = heap_alloc (strlen (layerName)+1)) <= 0)
        {   dxf__error_room ("DxfZG");
            layer->name = 0;
            return FALSE;
        }

        strcpy (layer->name, layerName);
        layer->colour = intVars [0];

        /*Look for line type name and turn it into an index*/
        layer->lineType = -1;
        if (dxf__lineTypes)
        {   for (index = 0; dxf__lineTypes [index]; index++)
              if (strcmp (linetypeName, dxf__lineTypes [index]) == 0)
                  break;
          if (dxf__lineTypes [index])
              layer->lineType = index;
        }

        layer += 1;

        /*Next item*/
        if ((group = dxf__readGroup ()) != 0)
        {   if (group != -1) dxf__error ("DxfG7");
            return FALSE;
        }
    }

    /*Terminate layer table*/
    layer->name = NULL;
    layer->colour = dxf__varInt.s.cecolor;
    layer->lineType = -1;

    DEBUG (" layer]");
    if (dxf__stringMatch ("ENDTAB"))
        return TRUE;
    else
    {   dxf__error_endtab ("DxfZ2");
        return FALSE;
    }
}

/*
 Function    : dxf__skip_to_endtab
 Purpose     : skip until we hit an endtab or the end of file
 Parameters  : error message
 Returns     : TRUE if found
*/

static BOOL dxf__skip_to_endtab (char *message)

{   BOOL match = FALSE;
    int group;

    /*Scan up to ENDTAB*/
    do
    { group = dxf__readGroup ();

      if (group == 0)
        match = dxf__stringMatch ("ENDTAB");
      else if (group == -1)
        match = FALSE;
    }
    while (group >= 0 && !match);

    /*Check we found an ENDTAB*/
    if (match)
        return TRUE;
    else
    {   dxf__error_endtab (message);
        return FALSE;
    }
}

/*
 Function    : dxf__readStyleTable
 Purpose     : read style table
 Parameters  : maximum size of table
 Returns     : TRUE if read OK
 Description : the style table is skipped - we read up to the ENDTAB.
*/

static BOOL dxf__readStyleTable (int maxSize)

{
    DEBUG (" [style] ");
    maxSize = maxSize;               /*Get rid of annoying warning message*/
    return dxf__skip_to_endtab ("DxfZ3");
}

/*
 Function    : dxf__readViewTable
 Purpose     : read view table
 Parameters  : maximum size of table
 Returns     : TRUE if read OK
 Description : the view table is skipped - we read up to the ENDTAB, or any
               other 0 group.
*/

static BOOL dxf__readViewTable (int maxSize)

{
    DEBUG (" [view]");
    maxSize = maxSize;               /*Get rid of annoying warning message*/
    return dxf__skip_to_endtab ("DxfZ4");
}

/*
 Data Group  : entities decoder array
 Description : table for decoding entities. Action type 99 means skip.
               Some entities are rendered by other code: BLOCK, VERTEX
*/
static dxf__decoderTable dxf__entitiesTable [] =
{   "LINE",       1, 0,
  "POINT",      2, 0,
  "CIRCLE",     7, 0,
  "ARC",        6, 0,
  "TRACE",      3, 0,
  "SOLID",      3, 1,
  "TEXT",       4, 0,
  "SHAPE",     99, 0,
  "INSERT",     8, 0,
  "ATTDEF",    99, 0,
  "ATTRIB",    99, 0,
  "SEQEND",    99, 0,         /*For attribute sequences*/
  "POLYLINE",   5, 0,
  "3DLINE",    99, 0,
  "3DFACE",    99, 0,
  "DIMENSION", 99, 0,         /*Skip for now*/
   NULL,        0, 0
};

/*
 Function    : dxf__drawEntity
 Purpose     : draw an entire entity sequence
 Parameters  : terminator
               new context
 Returns     : TRUE if successful
 Description : the sequence is rendered entity by entity until the specified
               terminator group (normally ENDSEC or ENDBLK) is seen.
               The entity decoder must load its own parameters, and return with
               the file pointer just before the next 0 group.
*/

BOOL dxf__drawEntity (char *terminator, dxf__context *c)

{   int group;
    BOOL extra, ok;

    DEBUG (" [drawEntity ");
    if ((group = dxf__readGroup ()) != 0)
    {   if (group != -1) dxf__error_group ("DxfZN");
        return FALSE;
    }

    while (!dxf__stringMatch (terminator))
    {   /*Look up object type, and render entity*/
        switch (dxf__decodeByTable
                     (state.groupString, dxf__entitiesTable, &extra))
        {   case 1: ok = dxf__renderLine (c); break;
            case 2: ok = dxf__renderPoint (c); break;
            case 3: ok = dxf__renderTrace (c, extra); break;
            case 4: ok = dxf__renderText (c); break;
            case 5: ok = dxf__renderPolyline (c); break;
            case 6: ok = dxf__renderArc (c); break;
            case 7: ok = dxf__renderCircle (c); break;
            case 8: ok = dxf__renderInsert (c); break;
            case 99:                    /*Skip object*/
                ok = TRUE;
                break;
            default: dxf__error ("DxfO2");
                return FALSE;
        }

        if (!ok) return FALSE;

        /*Skip on to next 0 group (usually next item)*/
        while ((group = dxf__readGroup ()) > 0);
        if (group < 0) return FALSE;
    }

    DEBUG (" drawEntity]");
    return TRUE;
}

/*****************************************************************************
  Level 2 (section) file reading
 *****************************************************************************/

/*
 Data Group  : variables decoder array
 Description : table for reading variables. Action type indicates the group
               type to be read, and extra the index into the relevant table.
*/

static dxf__decoderTable dxf__variablesTable [] =
{   "$ANGBASE",    50, DXF__angbase,
  "$ANGDIR",     70, DXF__angdir,
  "$CECOLOR",    62, DXF__cecolor,
  "$CELTYPE",     6, DXF__celtype,
  "$CLAYER",      8, DXF__clayer,
  "$GRIDMODE",   70, DXF__gridmode,
  "$GRIDUNIT",   10, DXF__gridunit,
  "$LIMMAX",     10, DXF__limmax,
  "$LIMMIN",     10, DXF__limmin,
  "$OSMODE",     70, DXF__osmode,
  "$PLINEWID",   40, DXF__plinewid,
  "$SNAPMODE",   70, DXF__snapmode,
  "$SNAPUNIT",   10, DXF__snapunit,
  "$TEXTSIZE",   40, DXF__textsize,
  "$VIEWCTR",    10, DXF__viewctr,
   NULL,          0, 0
};

/*
 Function    : dxf__readHeader
 Purpose     : read HEADER section
 Parameters  : void
 Returns     : TRUE if ok, FALSE on error
 Description : the header section consists of a sequence of 9,variable groups,
               followed by their arguments. The action code in the table
               indicated the type of argument that follows, and the extra code
               gives an index into the system variables array.
               Variables not in the table are ignored.
*/

static BOOL dxf__readHeader (void)

{   int group;                                       /*Group code*/
    int arggroup;                                    /*Argument group*/
    int index;                                       /*Index into array*/
    BOOL ok;

    DEBUG (" [readHeader ");
    group = dxf__readGroup ();

    do
    {   /*Find next variable*/
        if (group == 9)
        {   arggroup = dxf__decodeByTable
                         (state.groupString, dxf__variablesTable, &index);

            /*Read variable value*/
            if (arggroup < 0)
                ok = TRUE;       /*Ignore variable*/
            else if (arggroup < 10)
                ok = dxf__readString (arggroup, dxf__varString.a+index, TRUE);
            else if (arggroup < 30)
            {   ok = dxf__readCoord (arggroup, dxf__varCoord.a+index);
                DXFtoDraw = dxf__baseUnit * ((dxf__millimetres)
                                             ? DXF__millimetres : DXF__inches);
            }
            else if (arggroup < 60)
                ok = dxf__readFloat (arggroup, dxf__varFloat.a+index);
            else
                ok = dxf__readInt (arggroup, dxf__varInt.a+index);

            if (!ok) return FALSE;

            /*Skip to next variable, or end of section*/
            while ((group = dxf__readGroup ()) != 9 && group > 0)
               ;
        }
    } while (group == 9);

    /*Check for end of section*/
    DEBUG (" readHeader]");
    if (group == 0)
        return (dxf__stringMatch ("ENDSEC"));
    else if (group > 0)
        dxf__error ("DxfH1");

    return FALSE;
}

/*
 Data Group  : table types
 Description :
*/

static dxf__decoderTable dxf__tablesTable [] =
{   "LTYPE",  1, 0,
    "LAYER",  2, 0,
    "STYLE",  3, 0,
    "VIEW",   4, 0,
     NULL,    0, 0
};

/*
 Function    : dxf__readTables
 Purpose     : read TABELS section
 Parameters  : void
 Returns     : TRUE if ok, FALSE on error
 Description : each table consists of 0,TABLE, the table type, a 70 group
               giving the maximum size, and the table itself. We read the type
               and the 70 group here, and then pass into specific table
               readers, which read up to and including the ENDTAB group.

               When all the tables have been read, the font table is set up.
               This means that it is essential that the file header, and only
               the file header, have been output to the Draw area up to this
               point. As we do this, the list of fonts known to Draw is
               searched; if the font cannot be found, it is omitted from the
               font table.
*/

static BOOL dxf__readTables (void)

{   BOOL ok;
    int tableAction;
    int dummy, group;

    DEBUG (" [readTables ");
    if ((group = dxf__readGroup ()) != 0)
    {   if (group != -1) dxf__error ("DxfG8");
        return FALSE;
    }

    /*Check for end of section*/
    while (!dxf__stringMatch ("ENDSEC"))
    {   /*Check for 0,table*/
        if (dxf__stringMatch ("TABLE"))
        {   /*Read the type of table*/
            if ((group = dxf__readGroup ()) != 2)
            {   if (group != -1) dxf__error ("DxfT1");
                return FALSE;
            }
            tableAction = dxf__decodeByTable
                              (state.groupString, dxf__tablesTable, &dummy);

            /*Read the maximum table size*/
            if ((group = dxf__readGroup ()) != 70)
            {   if (group != -1) dxf__error ("DxfT2");
                return FALSE;
            }

            /*Pass into table reader itself*/
            switch (tableAction)
            {   case 1:
                    ok = dxf__readLtypeTable (state.groupInt);
                    break;
                case 2:
                    ok = dxf__readLayerTable (state.groupInt);
                    break;
                case 3:
                    ok = dxf__readStyleTable (state.groupInt);
                    break;
                case 4:
                    ok = dxf__readViewTable (state.groupInt);
                    break;
                default: dxf__error ("DxfT3");
                    return FALSE;  /*Unknown table*/
            }

            if (!ok) return FALSE;

            /*Next table*/
            if ((group = dxf__readGroup ()) != 0)
            {   if (group != -1) dxf__error_group ("DxfZO");
                return FALSE;
            }
        }
        else
        {   dxf__error ("DxfT4");
            return FALSE;
        }
    }

    /*Create the font table: at present, just the standard font*/
    /*The font list is not created if the font is not defined, or is
       not known
*/
    dxf__standardFontNumber = 0; /*In case font not found*/
    if (dxf__standardFont [0] != '\0')
    {   int i;
        int objsize;

        /*FIX JRC 22 Oct '91 < was <= below*/
        for (i = 1; i < draw_fontcat.list_size; i++)
        {   if (draw_file_matches (dxf__standardFont, draw_fontcat.name [i]))
            {   /*Font found - create the table*/
                objsize = sizeof (draw_fontliststrhdr) +
                          sizeof (draw_fontref) + strlen (dxf__standardFont) + 1;
                objsize = (objsize + 3) & (-4); /*plus 0..3 nulls to a word*/

                if (draw_obj_checkspace (dxf__diag, objsize))
                {   dxf__error_room ("DxfZH");
                    return FALSE;
                }

                draw_obj_start (dxf__diag, draw_OBJFONTLIST);

                /*Output font as number i. This is necessary so we can bound
                   the text before the fontcat has been merged*/
                draw_obj_addfontentry (dxf__diag, i , dxf__standardFont);
                draw_obj_addtext_term (dxf__diag);  /*pad to word boundary*/
                draw_obj_complete (dxf__diag);

                dxf__standardFontNumber = i;
                break;
            }
        }
    }

    DEBUG (" readTables]");
    return TRUE;
}

/*Data tables for BLOCKS section*/
static int dxf__blocksInt []    = {70 /*flags*/, -1};
static int dxf__blocksCoord []  = {10 /*insertion point*/, -1};
static int dxf__blocksString [] = {2  /*name*/, -1};

/*
 Function    : dxf__readBlocks
 Purpose     : read BLOCKS section
 Parameters  : void
 Returns     : TRUE if ok, FALSE on error
 Description : the block is logged in an internal data structure. This will be
               turned into real draw entities when an INSERT for the block is
               seen, in the ENTITIES section.
               Anonymous blocks are given a null name. Note that files from
               OAK appear to set the anonymous bit in blocks, but still
               supply a name. So we cannot rely on this bit.
*/

static BOOL dxf__readBlocks (void)

{   DXF__block *newblock;
    int group;
    int linetype;
    double thickness;
    int colour;
    /*Additional blocks data*/
    int flags;
    char *stringVars [1];
    char blockName [dxf__maxBuffer];
    DXF__item *item, *lastItem;

    DEBUG (" [readBlocks ");
    stringVars [0] = blockName;
    blockName [0]  = '\0';

    if ((group = dxf__readGroup ()) != 0)
    {   if (group != -1) dxf__error ("DxfG9");
        return FALSE;
    }

    while (!dxf__stringMatch ("ENDSEC"))
    {   if (dxf__stringMatch ("BLOCK"))
        {   /*Allocate space for the block*/
            if ((int) (newblock = heap_alloc (sizeof (DXF__block))) <= 0)
            {   dxf__error_room ("DxfZI");
                newblock = 0;
                return FALSE;
            }
            if (dxf__blockHead == NULL)
                dxf__blockHead = dxf__blockTail = newblock;
            else
            {   dxf__blockTail->next = newblock;
                dxf__blockTail       = newblock;
            }

            newblock->next = NULL;

            /*Read block common information*/
            Dxf_getCommon;

            /*Record common information for this block*/
            newblock->colour    = colour;
            newblock->linetype  = linetype;
            newblock->thickness = thickness;

            /*Read the block name, flags and base point*/
            if (!dxf__readGeneralBlock (dxf__blocksInt,    &flags,
                                       dxf__nullParam,    NULL,
                                       dxf__blocksCoord,  & (newblock->base),
                                       dxf__blocksString, stringVars))
            {   return FALSE;
            }

            /*Make name permanent*/
            if ((int) (newblock->name = heap_alloc (strlen (blockName)+1)) <= 0)
            {   dxf__error_room ("DxfZJ");
                newblock->name = 0;
                return FALSE;
            }
            strcpy (newblock->name, blockName);

            /*Read items into the block store until we hit ENDBLK*/
            lastItem = NULL;
            while ((group = dxf__readGroup ()) > 0
                   || !dxf__stringMatch ("ENDBLK"))
            {   if ((int) (item = heap_alloc (sizeof (DXF__item))) <= 0)
                {   dxf__error_room ("DxfZK");
                    item = 0;
                    return FALSE;
                }

                if (lastItem == NULL)
                    newblock->items = item;
                else
                    lastItem->next = item;
                item->next = NULL;
                lastItem = item;

                item->group = group;
                if (group <= 9)
                {   if ((int) (item->data.s
                              = heap_alloc (strlen (state.groupString)+1)) <= 0)
                    {   dxf__error_room ("DxfZL");
                        item->data.s = 0;
                        return FALSE;
                    }
                    strcpy (item->data.s, state.groupString);
                }
                else if (group < 60)
                    item->data.f = state.groupFloat;
                else
                    item->data.i = state.groupInt;

                if (group < 0) return FALSE;
            }

            /*Fetch next block header (or end)*/
            /*AutoSketch seems to sometimes put in an extra 8 group here*/
            if ((group = dxf__readGroup ()) != 0)
            {   int group1 = 0;

                if (group != 8 || (group1 = dxf__readGroup ()) != 0)
                {   if (group != -1 && group1 != -1)
                        dxf__error ("DxfB1");
                    return FALSE;
                }
            }
        }
    }

    DEBUG (" readBlocks]");
    return TRUE;
}

/*
 Function    : dxf__readEntities
 Purpose     : read ENTITIES section
 Parameters  : basex, basey (draw units)
               scale factor
 Returns     : TRUE if ok, FALSE on error
 Description : call draw entity, with ENDSEC as terminator
*/

static BOOL dxf__readEntities (int basex, int basey)

{   dxf__context context;
    int start_offset = dxf__diag->misc->ghostlimit;

    DEBUG (" [readEntities ");
    /*Set context base point to 0,0*/
    context.base.x = context.base.y = 0.0;

    /*Set defaults in block globals from system variables*/
    dxf__varInt.s.blockcolour      = dxf__varInt.s.cecolor;
    dxf__varInt.s.blocklineType    = -1;
    dxf__varFloat.s.blockthickness = -1.0;

    if (dxf__drawEntity ("ENDSEC", &context))
    {   dxf__coord scale  = {1.0, 1.0};

        dxf__transform (start_offset, dxf__diag->misc->ghostlimit,
                       basex, basey, &scale, TRUE);
    DEBUG (" readEntities]");
        return TRUE;
    }
    else
    {   dxf__error ("DxfE2");
        return FALSE;
    }
}


/*****************************************************************************
  Level 1 (top level) file reading
 *****************************************************************************/

/*
 Data Group  : section types
 Description : table for top level section types
*/

static dxf__decoderTable dxf__sectionsTable [] =
{   "HEADER",   1, 0,
    "TABLES",   2, 0,
    "BLOCKS",   3, 0,
    "ENTITIES", 4, 0,
     NULL,      0, 0
};

/*
 Function    : dxf__readFile
 Purpose     : read the DXF file
 Parameters  : file pointer
               x, y base locations (draw units)
 Returns     : TRUE if no errors, FALSE if any error
 Description : this reads each section of the file, and calls the appropriate
               decoding routine at level 2. Each section starts with 0,SECTION.
               It is assumed the level 2 routine will return at the point after
               the 0,ENDSEC if there is no error.
               0,EOF marks the end of the file.
*/

static BOOL dxf__readFile (FILE *filePointer, draw_objcoord *base)

{   BOOL ok;            /*Return from level 2 routine*/
    BOOL eof = FALSE;   /*Set when EOF group seen*/
    int dummy, i, group;

    DEBUG (" [readFile ");

    /*Set defaults in the variables tables*/
    for (i = 0; i < DXF__maxVarInt; i++)
        dxf__varInt.a [i] = 0;
    for (i = 0; i < DXF__maxVarFloat; i++)
        dxf__varFloat.a [i] = 0.0;
    for (i = 0; i < DXF__maxVarCoord; i++)
    {   dxf__varCoord.a [i].x = 0.0;
        dxf__varCoord.a [i].y = 0.0;
    }
    dxf__varString.s.celtype = dxf__default_celtype;
    dxf__varString.s.clayer  = dxf__default_clayer;

    /*Set unit conversion*/
    DXFtoDraw = dxf__baseUnit * (
                   (dxf__millimetres) ? DXF__millimetres : DXF__inches);

    /*Read the file*/
    dxf__lineNumber = 0;
    dxf__set_to_file (filePointer);

    do
    {   /*Read group and check it's a section*/
        if ((group = dxf__readGroup ()) == 0)
        {   if (dxf__stringMatch ("SECTION"))
            {   /*Read section type*/
                if (dxf__readGroup () == 2)
                {   /*Find action*/
                    switch (dxf__decodeByTable
                               (state.groupString, dxf__sectionsTable, &dummy))
                    {   case 1:
                            ok = dxf__readHeader (); break;
                        case 2:
                            ok = dxf__readTables (); break;
                        case 3:
                            ok = dxf__readBlocks (); break;
                        case 4:
                            ok = dxf__readEntities (base->x, base->y); break;
                        default:
                            dxf__error ("DxfS1");
                            return FALSE;
                    }

                    if (!ok) return FALSE;
                }
            }
            else
                eof = dxf__stringMatch ("EOF");
        }
        else
        {   if (group != -1) dxf__error ("DxfS2");
           return FALSE;        /*Section group missing*/
        }
    } while (!eof);

    DEBUG (" readFile]");
    return TRUE;
}

/*
 Function    : dxf__freeMemory
 Purpose     : free memory
 Parameters  : void
 Returns     : void
 Description : each area of memory allocated is freed. The areas are:
               line type names
               line type name pointers
               layer names
               layer name pointers
               string variables (if changed from default)
               block data

               File buffer, if from RAM.
*/

#define Heap_Free(x) {heap_free (x); x = NULL;}

static void dxf__freeMemory (void)

{   int index;
    DXF__block *block, *nextBlock;
    DXF__item *item, *nextItem;

    DEBUG (" [freeMemory ");
    /*Free line type names*/
    if ((int)dxf__lineTypes)
    {   for (index = 0; dxf__lineTypes [index]; index++)
          Heap_Free (dxf__lineTypes [index]);

      /*Free line type name pointers*/
      Heap_Free (dxf__lineTypes);
    }

    /*Free layer names*/
    if ((int)dxf__layers)
    {   for (index = 0; dxf__layers [index].name; index++)
          Heap_Free (dxf__layers [index].name);

      /*Free layer name pointers*/
      Heap_Free (dxf__layers);
    }

    /*Free string variables (if changed from default)*/
    if (dxf__varString.s.celtype != dxf__default_celtype)
        Heap_Free (dxf__varString.s.celtype);

    if (dxf__varString.s.clayer != dxf__default_clayer)
        Heap_Free (dxf__varString.s.clayer);

    /*Free blocks memory*/
    for (block = dxf__blockHead; block; block = nextBlock)
    {   nextBlock = block->next;
        for (item = block->items; item; item = nextItem)
        {   nextItem = item->next;
            if (item->group <= 9)
                Heap_Free (item->data.s);
            Heap_Free (item);
        }
        if (block->name)
            Heap_Free (block->name);
        Heap_Free (block);
    }

    if (dxf__viaRam)
    {   flex_free ((flex_ptr) &dxf__fileBuffer);
        dxf__fileBuffer = NULL;
    }
    DEBUG (" freeMemory]");
}

/**************************************************************************/
/*Interface to Draw*/
/**************************************************************************/

/*Fetch a DXF file. The mouse location is (x, y) in draw units*/
BOOL draw_dxf_fetch_dxfFile (diagrec *diag, char *fileName, int length,
                             draw_objcoord *pt, BOOL viaRam)

{   BOOL ok;
    FILE *filePointer;

    DEBUG (" [fetch_dxf ");
    visdelay_begin ();

    /*Record the diagram structure*/
    dxf__diag = diag;

    /*Initialise block pointers*/
    dxf__blockHead = dxf__blockTail = NULL;
    dxf__layers = NULL;
    dxf__lineTypes = NULL;

    /*Save read mode*/
    dxf__viaRam = viaRam;

    /*Set up a file header*/
    if (draw_obj_checkspace (dxf__diag, sizeof (draw_fileheader)))
    {   dxf__error_room ("DxfZM");
        return FALSE;
    }
    draw_obj_fileheader (dxf__diag);

    /*Load the file*/
    if (!dxf__loadfile (fileName, length, &filePointer)) return FALSE;

    /*Set DXF load options*/
    visdelay_end ();
    ok = draw_dxf_setOptions ();
    visdelay_begin ();

    /*Process the file*/
    if (ok) ok = dxf__readFile (filePointer, pt);

    /*Free up any memory used*/
    dxf__freeMemory ();

    /*Close file if need be*/
    if (!dxf__viaRam) fclose (filePointer);

    visdelay_end ();
    DEBUG (" fetch_dxf]");
    return (ok);
}
