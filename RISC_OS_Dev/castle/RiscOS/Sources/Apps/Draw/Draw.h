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
/* -> Draw.h
 *
 * Main header for Draw
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.14
 * History: 0.10 - 12 June 1989 - headers added. Old code weeded.
 *                                converted to use drawmod for paths
 *                                more use of bit fields
 *          0.11 - 19 June 1989 - drawObjects extracted
 *          0.12 - 29 June 1989 - name changes. Title moved to view record
 *          0.13 - 19 July 1989 - merged some field structures
 *          0.14 - 25 July 1989 - gave the states more mnemonic names
 *
 */

/* RELEASE VALUES */

#define VALIDATEFILES          1
#define REJECTUNKNOWNOBJECTS   0
#define ALLOWCTRLKEYS          0
#define ALLOW_DFILES           0
#define ALLOWCURSORKEYS        1
#define HOLLOWBLOB             1
#define REJECTUNKNOWNFILETYPES 1 /*Changed to 1. JRC 1 Feb 1990*/
#define USEHEAP                0 /*no need any more*/
#define FREEZE_STACK           0
#if TRACE
  #define CATCH_SIGNALS        1
#else
  #define CATCH_SIGNALS        1
#endif
#define USE_TRUE_COLOURS       1
#define HIGH_RES_LINES         0 /*Do this if for some reason bboxes must match exactly. Not done now <= too expensive.*/

#if USEHEAP
  /* Dynamic memory allocation */
  #ifndef __heap_h
    #include "heap.h"
  #endif

  #define Alloc(x)  (ftracef1 ("heap_alloc (%d)\n", x), heap_alloc (x))
  #define Free(x)   (ftracef1 ("heap_free (0x%X)\n", x), heap_free (x))
#else
  #define Alloc(x)  malloc(x)
  #define Free(x)   free(x)
#endif

#define whether(c) ((c)? "true": "false")

/* Useful definitions for file load/save */
#define filetypetext            'D','r','a','w'
#define majorformatversionstamp 201
#define minorformatversionstamp 0
#define programidentity         'D','r','a','w',' ',' ',' ',' ',' ',' ',' ',' '

#define filename_whole          msgs_lookup("FileDr") /*Offered if no title    */
#define filename_selection      msgs_lookup("FileSe") /*Always offered to user */
#define filename_sprite         msgs_lookup("FileSp") /*Always offered to user */
#define filename_textarea       msgs_lookup("FileTa") /*Always offered to user */

/* Sizes */
#define dbc_OneInch       (180 << 8)    /* 180 graphic coords per inch */
#define dbc_HalfInch       (90 << 8)
#define dbc_QuarterInch    (45 << 8)
#define dbc_FifthInch      (36 << 8)
#define dbc_TenthInch      (18 << 8)
#define dbc_TwentythInch    (9 << 8)

#define dbc_OneCm              18144    /* }        */
#define dbc_HalfCm              9072    /* } only   */
#define dbc_QuarterCm           4536    /* } approx */
#define dbc_EighthCm            2268    /* }        */

#define dbc_QuarterPoint         160
#define dbc_HalfPoint            320
#define dbc_OnePoint             640    /* 640 dBase coords per point */
#define dbc_TwoPoint            1280
#define dbc_FourPoint           2560
#define dbc_EightPoint          5120
#define dbc_TenPoint            6400
#define dbc_TwelvePoint         7680
#define dbc_FourteenPoint       8960
#define dbc_TwentyPoint        12800
#define dbc_OneThousandPoint  640000

/* A4 paper sizes.
   A4 is 297 mm long = 297/25.4 inches = 297/25.4 * 180 * 256 Draw units
         210 mm wide = 210/25.4 inches = 210/25.4 * 180 * 256 Draw units */
/* #define dbc_A4long    (2115<<8) */
/* #define dbc_A4short   (1485<<8) */
#define dbc_A4long  (538809)
#define dbc_A4short (380976)

#define dbc_WorldX0 (-4*dbc_A4long)  /*An area bigger than A0 (the largest*/
#define dbc_WorldY0 (-4*dbc_A4long)  /*paper size) to restrict points to.*/
#define dbc_WorldX1 (8*dbc_A4long)
#define dbc_WorldY1 (8*dbc_A4long)

#define dbc_StdCircRad (2115<<8)

/* Macros for converting between units, for text */
#define draw_pointsToDraw(pp)  ((pp) * 640)
int draw_pointsToFont(int xx);
int draw_drawToFont(int xx);
int draw_fontToDraw(int xx);
int draw_fontToOS(int xx);

/* Colour used for work area background */
#define Window_WORKBG 0

#define FILENAMEMAX 256 /* max 255 char + null */
#define TITLEBUFMAX 256 /* max 255 char + null (in case of future modes) */
#define UNTITLED    msgs_lookup("DrawUn")
#define UNUSED_SA   (sprite_area *)0x8000 /* Vaguely valid address */

#define grabW 16                /* Width and height of grab boxes */
#define grabH 16

#define TRANSPARENT 0xFFFFFFFF  /* Special, all other colours are */
#define BLACK       0x00000000  /*           bbggrr00             */
#define WHITE       0xFFFFFF00

#define THIN  0       /* thinest line (point)            */
#define SOLID 0       /* no dash pattern (draw_dashstr*) */

#define MAXZOOMFACTOR 8     /* highest magnification factor */

#define default_PAPERSIZE     2048  /* 2K bytes                        */
#define incfact_PAPERSIZE       20  /* extra needed + 20% current size */
#define default_SELECTIONSIZE  256  /* 256 entries                     */

#define default_FONTREF            0  /* system font */
#define default_FONTSIZEX       4096  /* 8 pixels wide mode 12 */
#define default_FONTSIZEY       8192  /* 8 pixels high mode 12 */

/*The largest coordinate anything may have. Reasoning: we must be able to
draw the bbox of the thing using bbc_plot() calls, so it must be at most
0x7FFF O S units big at a zoom factor of 8:1.*/

/*In fact, that's too small - throw a factor 8 back in again. Large objects
don't work at large zoom factors.*/
#define MAX_COORD (0x6FFF << 8)

/* Numbers of toolbox icons */
#define tbi_line_o 0
#define tbi_line_c 1
#define tbi_curv_o 2
#define tbi_curv_c 3
#define tbi_move   4
#define tbi_text   5
#define tbi_rect   6
#define tbi_elli   7
#define tbi_select 8

#define MAX(a, b) ((a) > (b)? (a): (b))
#define MIN(a, b) ((a) < (b)? (a): (b))

/* 'select' mode, expect Space,Object,Rotate,Stretch */
/* 'edit'submode, expect Space,Object,Control        */
typedef enum                    /* Position of mouse click */
{ overSpace,
  overObject,
  overRotate,
  overStretch,

  overMoveEp,
  overLineEp,
  overCurveB1,
  overCurveB2,
  overCurveEp
} region;

/* Each diagram has a mainstate and a substate. Mainstates are the general
   operation, substates the steps within that. In the following type,
   substates may take on any value. Mainstate may only take on values
   marked [*]
*/

typedef enum
{
  state_path,  /* Entering a path object [*] */
   state_path_move,   /* Placing initial point of a subpath */
   state_path_point1, /* Placing first  point of a line or curve */
   state_path_point2, /* Placing second point of a line or curve */
   state_path_point3, /* Placing >=3rd  point of a line or curve */

  state_text,  /* Entering a text object [*] */
   state_text_caret,  /* Caret in place, empty text */
   state_text_char,   /* Text entered */

  state_sel,   /* Start state for select mode [*] */
   state_sel_select,  /* 'select' drag a box to select objects   */
   state_sel_adjust,  /* 'adjust' drag a box to adjust selection */
   /*These two added by JRC 11 Oct 1990*/
   state_sel_shift_select,  /* shift-'select' drag a box to select objects*/
   state_sel_shift_adjust,  /* shift-'adjust' drag a box */
   state_sel_trans,   /* 'select' on object, translate selection */
   state_sel_scale,   /* 'select' on stretch box, scale selection */
   state_sel_rotate,  /* 'select' on rotate box, rotate selection */

  state_edit,  /* Start state for edit mode [*] */
   state_edit_drag,   /* Dragging a point during path edit */
   state_edit_drag1,  /* Dragging two points by bezier 1 during path edit.*/
   state_edit_drag2,  /* Dragging two points by bezier 2 during path edit.*/

  state_rect,  /* start state for rectangle entry [*] */
   state_rect_drag,   /* Rectangle drag in progress */

  state_elli,  /* start state for ellipse entry [*] */
   state_elli_drag,   /* Ellipse drag in progress */

  state_zoom,  /* dragging zoom box [*] */

  state_printerI, /* dragging inner printer limits [*] */
  state_printerO  /* dragging outer printer limits [*] */

} draw_state;

/* Flags - contain various diagram level status */
typedef struct
{ /* Entry options */
  unsigned int curved : 1;
  unsigned int closed : 1;

  /* Diagram modified flag */
  unsigned int modified : 1;

  /*Set for a diagram read from a file of type DrawFile, and when a diagram
    is saved to a file. In both cases, the diagram "is" the file. Controls
    datestamp setting.*/
  unsigned int datestamped: 1;
} diag_options;

/* Flags - contain various view level status */
typedef struct
{ unsigned int show   : 1;
  unsigned int lock   : 1;

  unsigned int  xinch : 1;
  unsigned int  xcm   : 1;
  unsigned int  yinch : 1;
  unsigned int  ycm   : 1;

  unsigned int  rect  : 1;
  unsigned int  iso   : 1;

  /* Auto adjust on close or wide points */
  unsigned int  autoadj : 1;

  /* Lock zoom to powers of two */
  unsigned int  zoomlock : 1;

  /* Tool pane shown */
  unsigned int  showpane : 1;
} viewflags_typ;

/* Indices (must match order on menus) */
#define grid_X    0
#define grid_Y    1
#define grid_Inch 0
#define grid_Cm   1

typedef struct
{
  /* each of the following is indexed by x=0, y=1 */
  double space[2];         /* Space between major points */
  int    divide[2];        /* Divisions of a mjor space */
} gridparams;

typedef int draw_sizetyp;

/* draw_bboxtyp is used for bounding boxes and some other boxes expressed in
   draw coordinates (this is usually better than passing four separate ints)
*/
typedef struct { int x0,y0, x1,y1; } draw_bboxtyp;
typedef unsigned int draw_coltyp;

typedef int draw_pathwidth;   /* 1 word */

/* Values for the following two are defined in drawmod.h */
typedef int draw_jointyp;
typedef int draw_captyp;

typedef enum
{ wind_nonzero = 0,
  wind_evenodd = 1
} draw_windtyp;

typedef enum
{ dash_absent  = 0,
  dash_present = 1
} draw_dashtyp;

/* These are used to pack and unpack the draw_pathstyle */
#define packmask_join     0x03
#define packmask_endcap   0x0C
#define packmask_startcap 0x30
#define packmask_windrule 0x40
#define packmask_dashed   0x80
#define packshft_join        0
#define packshft_endcap      2
#define packshft_startcap    4
#define packshft_windrule    6
#define packshft_dashed      7

/* Macro to pack the whole lot down */
#define pathpack(join, end, start, wind) ((join)  << packshft_join)     | \
                                         ((end)   << packshft_endcap)   | \
                                         ((start) << packshft_startcap) | \
                                         ((wind)  << packshft_windrule)

/* Path style */
typedef union
{ struct                             /* Bit field format */
  { unsigned int join      : 2;
    unsigned int endcap    : 2;
    unsigned int startcap  : 2;
    unsigned int windrule  : 1;
    unsigned int dashed    : 1;
    unsigned int reserved8 : 8;      /* 1 byte  */
    unsigned int tricapwid : 8;      /* 1 byte  */ /*1/16th of line width */
    unsigned int tricaphei : 8;      /* 1 byte  */ /*1/16th of line width */
  } s;
  struct                             /* Packed format */
  { unsigned char style;             /* 1 byte  */ /*bit 0..1 join        */
                                                   /*bit 2..3 end cap     */
                                                   /*bit 4..5 start cap   */
                                                   /*bit 6    winding rule*/
                                                   /*bit 7    dashed      */
    unsigned char reserved8;         /* 1 byte  */
    unsigned char tricapwid;         /* 1 byte  */ /* 1/16th of line width*/
    unsigned char tricaphei;         /* 1 byte  */ /* 1/16th of line width*/
  } p;
  int i;
} draw_pathstyle;

/* ---------------------------------------------------------------------- */

typedef enum
{ Paper_Show  = 1,
  Paper_Limit = 2,

  Paper_Landscape = 0x10,  /* set/clear = landscape/portrait */

  Paper_Default   = 0x100  /* printer limits are default */
} paperoptions_typ;

typedef enum
{ Paper_A0 = 0x100,
  Paper_A1 = 0x200,
  Paper_A2 = 0x300,
  Paper_A3 = 0x400,
  Paper_A4 = 0x500,
  Paper_A5 = 0x600
} papersize_typ;

typedef struct
{ draw_bboxtyp pagelimit;     /* physical edge of paper */
  draw_bboxtyp visiblelimit;  /* usable print area      */
} printmargin_typ;

typedef struct
{ BOOL present;
  /* New style printer information - only one box */
  printmargin_typ box;
} printer_typ;

typedef struct
{
  papersize_typ size;         /* A3/4/5             */
  paperoptions_typ options;   /* landscape/portrait */
  draw_bboxtyp viewlimit;
  draw_bboxtyp setlimit;      /* (Outer) limits as set by user */
} paperstate_typ;

#define Paper_DefaultSize    (Paper_A4)
#define Paper_DefaultOptions (Paper_Landscape)

/* Zoom factor - just a multiplier and a divisor */
typedef struct { int mul, div; } draw_zoomstr;

typedef char draw_fontref;    /* 1 byte */

typedef struct
{ draw_fontref fontref;             /* 1 byte  */
  char         reserved8;           /* 1 byte  */
  short        reserved16;          /* 2 bytes */
} draw_textstyle;   /* 1 word */

typedef int draw_fontsize;          /* 4 bytes */

typedef struct
  { int
      kerned: 1,       /*whether to kern the text on output*/
      direction: 1,    /*0 <=> left-to-right*/
      underline: 1;    /*1 <=> underline this text line*/
  }
  draw_fontflags;

typedef int coord;

typedef struct
{ int typeface;     /* index into fontname table */
  draw_fontsize typesizex;
  draw_fontsize typesizey;
  draw_coltyp textcolour;    /* text colour RGB */
  draw_coltyp background;    /* hint for anti-aliased printing RGB */
} fontrec;

typedef enum
{ draw_OBJFONTLIST     = 0,
  draw_OBJTEXT         = 1,
  draw_OBJPATH         = 2,
/*draw_OBJRECT         = 3,*/
/*draw_OBJELLI         = 4,*/
  draw_OBJSPRITE       = 5,
  draw_OBJGROUP        = 6,
  draw_OBJTAGG         = 7,
  draw_OBJTEXTAREA     = 9,
  draw_OBJTEXTCOL      = 10,
  draw_OPTIONS         = 11,
  draw_OBJTRFMTEXT     = 12,
  draw_OBJTRFMSPRITE   = 13,
  draw_OBJTRFMTEXTAREA = 14,
  draw_OBJTRFMTEXTCOL  = 15,
  draw_OBJJPEG         = 16,
  /*Add new types here*/

  draw_TAG_LIMIT       = 17 /*number of types*/
} draw_tagtyp;

typedef int draw_taggtyp;

/* draw_objcoord is used for coordinates and also for passing points in draw
   units (this is usually better than passing two separate ints)
*/
typedef struct { int x,y; } draw_objcoord;
typedef struct { double x, y;} draw_doublecoord;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* File header                                                            */
/*                                                                        */

typedef struct
{ char title[4];
  int  majorstamp;
  int  minorstamp;
  char progident[12];
  draw_bboxtyp   bbox;      /* 4 words */
} draw_fileheader;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* General header for graphic objects - on other objects, tag & size exist*/
/*                                     other fields are unused and may not*/
/*                                                                        */

typedef struct
{ draw_tagtyp    tag;       /* 1 word  */
  draw_sizetyp   size;      /* 1 word  */
  draw_bboxtyp   bbox;      /* 4 words */
} draw_objhdr;

/* -----------------------------------------------------------------------*/
/*                                                                        */
/* A font list                                                            */
/*                                                                        */

typedef struct
{ draw_tagtyp    tag;       /* 1 word  */
  draw_sizetyp   size;      /* 1 word  */
} draw_fontliststrhdr;

typedef struct
{ draw_tagtyp    tag;       /* 1 word  */
  draw_sizetyp   size;      /* 1 word  */

  draw_fontref   fontref;
  char           fontname[1];   /* String, null terminated */
} draw_fontliststr;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* A line of text                                                         */
/*                                                                        */

typedef struct
{ draw_tagtyp    tag;        /* 1 word  */
  draw_sizetyp   size;       /* 1 word  */
  draw_bboxtyp   bbox;       /* 4 words */
  draw_coltyp    textcolour; /* 1 word  */
  draw_coltyp    background; /* 1 word  */
  draw_textstyle textstyle;  /* 1 word  */
  draw_fontsize  fsizex;     /* 1 word  */
  draw_fontsize  fsizey;     /* 1 word  */
  draw_objcoord  coord;      /* 2 words */
} draw_textstrhdr;

typedef struct
{ draw_tagtyp    tag;        /* 1 word  */
  draw_sizetyp   size;       /* 1 word  */
  draw_bboxtyp   bbox;       /* 4 words */
  draw_coltyp    textcolour; /* 1 word  */
  draw_coltyp    background; /* 1 word  */
  draw_textstyle textstyle;  /* 1 word  */
  draw_fontsize  fsizex;     /* 1 word  */
  draw_fontsize  fsizey;     /* 1 word  */
  draw_objcoord  coord;      /* 2 words */

  char           text[1];   /* String, null terminated */
} draw_textstr;

typedef drawmod_path_tagtype draw_path_tagtype; /* Only lowest byte is used */

/* This entry is a fiddle! It was missed from drawmod.h */
typedef struct { drawmod_path_tagtype tag; } drawmod_path_termstr;

typedef union           /* Use ONLY for space checking purposes */
{ drawmod_path_movestr      a;
  drawmod_path_linetostr    b;
  drawmod_path_bezierstr    c;
  drawmod_path_closelinestr d;
  drawmod_path_termstr      e;
} largest_path_str;

/* A pseudo path_str to represent a closed rectangle */
typedef struct
{ drawmod_path_movestr     move;
  drawmod_path_linetostr   line1;
  drawmod_path_linetostr   line2;
  drawmod_path_linetostr   line3;
  drawmod_path_linetostr   line4;
  drawmod_path_closegapstr close;
  drawmod_path_termstr     term;
} path_pseudo_rectangle;

/* A pseudo path_str to represent a closed ellipse */
typedef struct
{ drawmod_path_movestr     move;
  drawmod_path_bezierstr   curve1;
  drawmod_path_bezierstr   curve2;
  drawmod_path_bezierstr   curve3;
  drawmod_path_bezierstr   curve4;
  drawmod_path_closegapstr close;
  drawmod_path_termstr     term;
} path_pseudo_ellipse;

typedef struct
{ drawmod_dashhdr dash;        /* distance into pattern + number of elements */
  int             elements[6]; /* dashcount words: elements of pattern       */
} draw_dashstr;

typedef struct
{ draw_pathwidth linewidth;
  draw_coltyp    linecolour;
  draw_coltyp    fillcolour;

  draw_dashstr* pattern;
  draw_jointyp  join;       /* 1 byte  */
  draw_captyp   endcap;     /* 1 byte  */
  draw_captyp   startcap;   /* 1 byte  */
  draw_windtyp  windrule;   /* 1 byte  */
  int           tricapwid;
  int           tricaphei;
} pathrec;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* A path                                                                 */
/*                                                                        */

typedef struct
{ draw_tagtyp    tag;        /* 1 word  */
  draw_sizetyp   size;       /* 1 word  */
  draw_bboxtyp   bbox;       /* 4 words */
  draw_coltyp    fillcolour; /* 1 word  */
  draw_coltyp    pathcolour; /* 1 word  */
  draw_pathwidth pathwidth;  /* 1 word  */
  draw_pathstyle pathstyle;  /* 1 word  */
} draw_pathstrhdr;

typedef struct
{ draw_tagtyp    tag;        /* 1 word  */
  draw_sizetyp   size;       /* 1 word  */
  draw_bboxtyp   bbox;       /* 4 words */
  draw_coltyp    fillcolour; /* 1 word  */
  draw_coltyp    pathcolour; /* 1 word  */
  draw_pathwidth pathwidth;  /* 1 word  */
  draw_pathstyle pathstyle;  /* 1 word  */

  draw_dashstr   data;       /* optional dash pattern, then path elements */
  int            PATH;
} draw_pathstr;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* A rectangle T.B.A                                                      */
/*                                                                        */

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* An ellipse T.B.A                                                       */
/*                                                                        */

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* A sprite                                                               */
/*                                                                        */

typedef struct
{ draw_tagtyp    tag;       /* 1 word  */  /* NB fileIO_xxx routines assume  */
  draw_sizetyp   size;      /* 1 word  */  /*    a draw_spristrhdr is all    */
  draw_bboxtyp   bbox;      /* 4 words */  /*    that needs adding to change */
} draw_spristrhdr;

typedef struct
{ draw_tagtyp    tag;       /* 1 word  */
  draw_sizetyp   size;      /* 1 word  */
  draw_bboxtyp   bbox;      /* 4 words */
  sprite_header  sprite;
  int            palette[1]; /* depends on sprite.mode (or not present) */
} draw_spristr;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* A grouping                                                             */
/*                                                                        */

typedef struct { char ch[12]; } draw_groupnametyp;  /* 12 bytes */

typedef struct
{ draw_tagtyp       tag;   /* 1 word   */
  draw_sizetyp      size;  /* 1 word   */
  draw_bboxtyp      bbox;  /* 4 words  */
  draw_groupnametyp name;  /* 12 bytes */
} draw_groustr;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* A tagged object                                                        */
/*                                                                        */

typedef struct
{ draw_tagtyp    tag;       /* 1 word  */
  draw_sizetyp   size;      /* 1 word  */
  draw_bboxtyp   bbox;      /* 4 words */
} draw_taggstrhdr;

typedef struct
{ draw_tagtyp    tag;       /* 1 word  */
  draw_sizetyp   size;      /* 1 word  */
  draw_bboxtyp   bbox;      /* 4 words */
  draw_taggtyp   tagg;      /* 1 word  */

  /*followed by a draw object and then some extra data*/
} draw_taggstr;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* A text column                                                          */
/*                                                                        */
/* These only appear nested within a text area                            */

typedef struct
{ draw_tagtyp    tag;        /* 1 word  */
  draw_sizetyp   size;       /* 1 word  */
  draw_bboxtyp   bbox;       /* 4 words */
} draw_textcolhdr;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* A text area object                                                     */
/*                                                                        */
/*                                                                        */

typedef struct
{ draw_tagtyp    tag;        /* 1 word  */
  draw_sizetyp   size;       /* 1 word  */
  draw_bboxtyp   bbox;       /* 4 words */
  draw_textcolhdr column;    /* Hook for pointing to text columns */
} draw_textareastrhdr;

typedef struct
{ draw_tagtyp    tag;        /* 1 word  */
  draw_sizetyp   size;       /* 1 word  */
  draw_bboxtyp   bbox;       /* 4 words */
  /* Text columns go in here */
} draw_textareahdr;

/* End structure - follows all the column */
typedef struct               /* Structure for getting size */
{
  int            endmark;    /* 1 word, always 0 */
  int            blank1;     /* 1 word, reserved for future expansion */
  int            blank2;     /* 1 word, reserved for future expansion */
  draw_coltyp    textcolour; /* 1 word */
  draw_coltyp    backcolour; /* 1 word */
  /* String goes in here */
} draw_textareastrend;

typedef struct
{
  int            endmark;    /* 1 word, always 0 */
  int            blank1;     /* 1 word, reserved for future expansion */
  int            blank2;     /* 1 word, reserved for future expansion */
  draw_coltyp    textcolour; /* 1 word */
  draw_coltyp    backcolour; /* 1 word */
  char           text[1];    /* String, null terminated */
} draw_textareaend;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* An options object - new and exciting - JRC 11 June 1990                */
/*                                                                        */

/*Options now global - JRC.*/
/* Type used for options read from options string */
typedef
  struct
  { struct
    { papersize_typ    size;
      paperoptions_typ o;
    }
    paper;
    struct
    { double space;
      int    divide;
      int    o[5]; /* iso, auto, show, lock, cm */
    }
    grid;
    struct
    { int mul, div;
      int lock;
    }
    zoom;
    int toolbox;
    struct
    { unsigned int   line : 1;
      unsigned int  cline : 1;
      unsigned int  curve : 1;
      unsigned int ccurve : 1;
      unsigned int   rect : 1;
      unsigned int   elli : 1;
      unsigned int   text : 1;
      unsigned int  select: 1;
    }
    mode;
    int undo_size; /* Undo buffer size in bytes */
  }
  draw_options;

typedef struct
{ draw_tagtyp    tag;        /* 1 word  */
  draw_sizetyp   size;       /* 1 word  */
  draw_bboxtyp   bbox;       /* 4 words - not used */
} draw_optionsstrhdr;

typedef struct
{ draw_tagtyp    tag;        /* 1 word  */
  draw_sizetyp   size;       /* 1 word  */
  draw_bboxtyp   bbox;       /* 4 words - not used */

  draw_options   options;

} draw_optionsstr;

/* -------------------------------------------------------------------------
 *
 * A transformed line of text
 *
 */

typedef struct
{ draw_tagtyp     tag;        /* 1 word  */
  draw_sizetyp    size;       /* 1 word  */
  draw_bboxtyp    bbox;       /* 4 words */
  drawmod_transmat trfm;       /* 6 words */
  draw_fontflags  flags;      /* 1 word  */
  draw_coltyp     textcolour; /* 1 word  */
  draw_coltyp     background; /* 1 word  */
  draw_textstyle  textstyle;  /* 1 word  */
  draw_fontsize   fsizex;     /* 1 word  */
  draw_fontsize   fsizey;     /* 1 word  */
  draw_objcoord   coord;      /* 2 words */
} draw_trfmtextstrhdr;

typedef struct
{ draw_tagtyp     tag;        /* 1 word  */
  draw_sizetyp    size;       /* 1 word  */
  draw_bboxtyp    bbox;       /* 4 words */
  drawmod_transmat trfm;       /* 6 words */
  draw_fontflags  flags;      /* 1 word  */
  draw_coltyp     textcolour; /* 1 word  */
  draw_coltyp     background; /* 1 word  */
  draw_textstyle  textstyle;  /* 1 word  */
  draw_fontsize   fsizex;     /* 1 word  */
  draw_fontsize   fsizey;     /* 1 word  */
  draw_objcoord   coord;      /* 2 words */

  char            text[1];   /* String, null terminated */
} draw_trfmtextstr;

/* -------------------------------------------------------------------------
 *
 * A transformed sprite
 *
 */

typedef struct
{ draw_tagtyp     tag;      /* 1 word  */ /*NB fileIO_xxx routines assume*/
  draw_sizetyp    size;     /* 1 word  */ /*a draw_spristrhdr is all*/
  draw_bboxtyp    bbox;     /* 4 words */ /*that needs adding to change*/
  drawmod_transmat trfm;     /* 6 words */ /*N B contains scaling info!*/
} draw_trfmspristrhdr;

typedef struct
{ draw_tagtyp     tag;      /* 1 word  */
  draw_sizetyp    size;     /* 1 word  */
  draw_bboxtyp    bbox;     /* 4 words */
  drawmod_transmat trfm;     /* 6 words */
  sprite_header   sprite;
  int             palette [1]; /*depends on sprite.mode (or not present)*/
} draw_trfmspristr;

/* -------------------------------------------------------------------------
 *
 * A transformed text area object
 *
 */

typedef struct
{ draw_tagtyp     tag;        /* 1 word  */
  draw_sizetyp    size;       /* 1 word  */
  draw_bboxtyp    bbox;       /* 4 words */
  drawmod_transmat trfm;       /* 6 words */
  draw_textcolhdr column;    /* Hook for pointing to text columns */
} draw_trfmtextareastrhdr;

typedef struct
{ draw_tagtyp     tag;        /* 1 word  */
  draw_sizetyp    size;       /* 1 word  */
  draw_bboxtyp    bbox;       /* 4 words */
  drawmod_transmat trfm;       /* 6 words */
  /* Text columns go in here */
} draw_trfmtextareastr;

/* ----------------------------------------------------------------------
 * A JPEG
 */

typedef struct
{ draw_tagtyp      tag;            /*draw_OBJJEG*/
  draw_sizetyp     size;           /*in bytes, of the whole object (aligned)*/
  draw_bboxtyp     bbox;           /*in DrawU*/
  int              width, height;  /*in DrawU*/
  int              xdpi, ydpi;     /*scale factors from jpegpixel to DrawU*/
  drawmod_transmat trans_mat;      /*transformation from DrawU to DrawU*/
  int              len;            /*in bytes, of the JPEG only*/
} draw_jpegstrhdr;

typedef struct
{ draw_tagtyp      tag;
  draw_sizetyp     size;
  draw_bboxtyp     bbox;
  int              width, height;
  int              xdpi, ydpi;
  drawmod_transmat trans_mat;
  int              len;
  jpeg_image       image;
} draw_jpegstr;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* A type that can point at any object or its sub-components              */
/*                                                                        */

typedef union
{ draw_objhdr         *objhdrp;

  draw_fileheader     *filehdrp;

  draw_fontliststrhdr *fontlisthdrp;
  draw_textstrhdr     *texthdrp;
  draw_pathstrhdr     *pathhdrp;
  draw_spristrhdr     *spritehdrp;
  draw_taggstrhdr     *tagghdrp;
  draw_textareastrhdr *textareastrp;
  draw_textareastrend *textareastrendp;
  draw_optionsstrhdr  *optionshdrp;
  draw_trfmtextstrhdr *trfmtexthdrp;
  draw_trfmspristrhdr *trfmsprihdrp;
  draw_trfmtextareastrhdr
                      *trfmtextareahdrp;
  draw_jpegstrhdr     *jpeghdrp;

  draw_fontliststr    *fontlistp;
  draw_textstr        *textp;
  draw_pathstr        *pathp;
  draw_spristr        *spritep;
  draw_groustr        *groupp;
  draw_taggstr        *taggp;
  draw_textareahdr    *textareap;
  draw_textareaend    *textareaendp;
  draw_textcolhdr     *textcolp;
  draw_optionsstr     *optionsp;
  draw_trfmtextstr    *trfmtextp;
  draw_trfmspristr    *trfmspritep;
  draw_trfmtextareastr*trfmtextareap;
  draw_jpegstr        *jpegp;

  draw_objcoord       *coordp;

  char *bytep;
  int  *wordp;
} draw_objptr;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* pathedit_str - data structure used in pathedit mode                    */
/*                                                                        */

typedef struct
{
  region over;   /* Space,TextAnchor,LineAnchor etc         */

  int obj_off;   /* position of object in dBase             */
  int sub_off;   /* sub_object if in a group, else =obj_off */

  /* if editing a path */
  int fele_off;  /* first element in subpath                */
  int pele_off;  /* previous (to current) element in path   */
  int cele_off;  /* current (highlighted) element of a path */

  int cor_off;   /* position of coordinate in dBase         */

  int corA_off;  /* endpoint being moved */
  int corB_off;  /* its equivalant moveto iff end of closed path */
  int corC_off;  /* this elements bez2 (if any) */
  int corD_off;  /* next elements bez1 (if any) */

  BOOL changed;  /* TRUE if a change was made */
  double ratio, angle;
                 /* for dragging two control points at once */
} pathedit_str;

/* ---------------------------------------------------------------------- */
/* Saved state and options */

typedef struct
{
  draw_state   state; /* Old editing state */
  diag_options opts;  /* Old editing options */
} diag_save;

/* ---------------------------------------------------------------------- */
/*                                                                        */
/* draw_viewstr - data structure for a view (window) onto a diagram.      */
/*                                                                        */

typedef struct drec *diagptr;

typedef struct vref
{ struct vref   *nextview;
  struct vref   *prevview;

  diagptr       diag;              /* pointer to parent diagram */

  wimp_w        w;                 /* window handle for this view */
  wimp_w        pw;                /* pane window holding our tools */
  wimp_box      lastextent;        /* last non-full extent */
  int           lastx, lasty;      /* last scroll values */

  draw_zoomstr  zoom;
  double        zoomfactor;        /* always zoom.mul/zoom.div */
  draw_zoomstr  lastzoom;          /* previous zoom */

  viewflags_typ flags;

  gridparams    gridunit[2];       /* indexed by inch=0, cm=1 */
  gridparams    grid;              /* current parameters, in dbc */

  draw_coltyp   gridcolour;
  char          *title;
} viewrec;

/* diagstr - data structure for a diagram.                                */
/*                                                                        */
/*  a diagram can have 0..draw_VIEWLIM views (windows) displayed at       */
/*  different zoom factors on screen.                                     */

typedef struct
{
  int solidstart;      /* offset to main data objects               */
  int solidlimit;      /* offset past main data objects             */
  int ghoststart;      /* offset to object construction area        */
  int ghostlimit;      /* offset past incomplete entry              */
  int stacklimit;      /* FD stack of offsets to incomplete entries */
  int bufferlimit;     /* buffer size                               */

  draw_state    mainstate;
  draw_state    substate;
  diag_options  options;

  paperstate_typ paperstate;  /* A3/4/5, port/lands, view limits */

  viewrec *wantsnulls; /* 0 or ptr to view to direct nulls to */

  pathrec path;
  fontrec font;

  int pta_off, ptb_off;
  int ptw_off, ptx_off, pty_off;
  int ptz_off;

  draw_objcoord ptzzz;           /* last mouse position */
  draw_objcoord ellicentre;

  char filename[FILENAMEMAX];
  struct {int load, exec;} address; /*The load and exec addresses of the
      file. diag->misc->address is only used when
      diag->misc->options.datastamped is set.*/

  int  vuuecnt;

  pathedit_str pathedit_cb;

  diag_save    save;             /* saved state in path edit */
} draw_diagstr;

typedef struct drec
{ struct drec      *nextdiag;
  struct drec      *prevdiag;

  draw_diagstr     *misc;
  char             *paper;
  viewrec          *view;   /* linked list of handles etc for each view */
  void             *undo;   /* pointer to undo buffer */
} diagrec;

extern diagrec       *draw_startdiagchain;
extern draw_objcoord  draw_stdcircpoints[13];

extern draw_fileheader draw_blank_header;

typedef struct               /* Structure passed to draw_action_zoom */
{ diagrec      *diag;        /* diag &                              */
  viewrec      *view;        /* view   to zoom in/out               */
  draw_zoomstr zoom;         /* new zoomfactor is zoom.mul/zoom.div */
} zoomchangestr;

typedef struct      /* cached values read by bbc_vduvars, so ordering */
                    /* is important, see cache_currentmodevars        */
{
  int gcharaltered; /* flag set if ArcDraw changes the system font size */

  int gcharsizex;   /* if so, restore from here */  /* first cached value */
  int gcharsizey;
  int gcharspacex;
  int gcharspacey;

  int ncolour;
  int xeigfactor;
  int yeigfactor;                                   /* last cached value  */

  int pixx;         /* in os units */
  int pixy;         /* in os units */
  int pixsizex;     /* in dBase coords, ie 0x100 << xeigfactor */
  int pixsizey;     /* in dBase coords, ie 0x100 << yeigfactor */

  int x_wind_limit, y_wind_limit;
  int mode;
} currentmodestr;

extern currentmodestr  draw_currentmode;
extern wimp_palettestr draw_palette; /* Current palette setting */

typedef struct
{ int skeleton;     /* in entry/path-edit mode */
  int anchorpt;
  int bezierpt;
  int highlight;

  int grid;         /* all modes */

  int bbox;         /* in select mode */

  int printmargin;
} coloursstr;

extern coloursstr draw_colours;   /* initialised from template file */

typedef struct
{ int menu_size;        /* Number found on start up                        */
  int list_size;        /* Same or includes extra found from file fontlist */
  char* name[256];      /* Space for names is malloced, so it won't move   */
} fontcatstr;

extern fontcatstr draw_fontcat;

typedef struct
{ int centreX,   centreY; /* Centre of rotation */
  double sinB,   cosB;    /* Angle 'centre(X,Y)_grab point(X,Y)' from Horz. */
  double sinA_B, cosA_B;
} rotat_str;

extern rotat_str draw_rotate_cb;

typedef draw_bboxtyp captu_str; /* currently enclosed area {dBase coords} */

extern captu_str draw_capture_cb;

typedef struct
{ int dx, dy;             /* {dBase coords} */
} trans_str;

extern trans_str draw_translate_cb;

typedef struct
{ int old_Dx, old_Dy; /* previous (width,height) */     /* {dBase coords} */
  int new_Dx, new_Dy; /* new      (width,height) */
} scale_str;

extern scale_str draw_scale_cb;

extern draw_options draw_current_options;
  /*Set at start up from initial_options and <Draw$Options>. Maintained
    by the routines that change state.*/

extern char draw_numvalid0[];
extern char draw_numvalid1[];
extern char draw_numvalid2[];

extern char draw_zero_str[];
extern char draw_one_str[];

extern BOOL draw_jpegs_rotate;
extern BOOL draw_fonts_blend;

extern int __root_stack_size;

extern void draw_set_dollar_options(void);
extern void draw_set_current_font(diagrec *diag, int, int,int);

/* as wimp_open_wind, but opens toolbox pane iff vuue->showpane set */
extern void draw_open_wind(wimp_openstr *main, viewrec *vuue);

extern os_error *draw_opennewdiag(diagrec **diagp, BOOL grab_selection);
extern os_error *draw_opennewview(diagrec *diag, viewrec **vuuep);

extern void draw_fillwindowtitle(viewrec *vuue);
extern void draw_toolbox_showall(diagrec *diag, int show);

extern void draw_modified(diagrec *diag);
extern void draw_modified_no_undo(diagrec *diag);

extern void draw_action_abandon(diagrec *diag); /* flush any object, restore screen */
extern void draw_action_changestate(diagrec *diag, draw_state, int,int, BOOL);

/* Convert between os and draw units, unscaled */
#define draw_os_to_draw(A)     ((int)(A) << 8)
#define draw_draw_to_os(A)     ((int)(A) >> 8)
#define draw_draw_to_osD(A)    ((double)(A) / 256)

extern int draw_scaledown(int A);
#define root3over2 (0.866025404)

extern void draw_set_caret(wimp_w w, int x, int y, int height);
extern void draw_get_focus(void);
extern void draw_kill_caret(void);

/* Macro for reporting errors via werr and msgs */
#define Error(level, code)  werr(level, msgs_lookup(code))

extern void draw_dispose_diag(diagrec *diag);
extern void draw_paper_close(viewrec *vuue);

extern void draw_start_capture(viewrec *vuue, draw_state state, draw_objcoord *pt,
                        BOOL abandon);

/* Sort coordinates */
extern void draw_sort(int *a, int *b);

extern void draw_setextent(viewrec *vuue);

/* Raw bounding box, used in routines which form bounds */
extern draw_bboxtyp draw_big_box;

extern void draw_make_clip(wimp_redrawstr *r, draw_objcoord *org, draw_bboxtyp *clip);

/* Set printer limits from capture box */
extern void draw_set_paper_limits(diagrec *diag, captu_str box);

/* Reset VDU 5 character size after change */
extern void draw_reset_gchar(void);

/* Conjure an OS error from a Draw message token */
extern os_error *draw_make_oserror(const char *token);

/*-----------------------------------------------------------------------*/
/* Some of the following functions are actually declared in c.drawAction */

/* Does a scaledown, applying the origin shift first */
/* Each argument points to two integers, i.e. x, y */
extern void draw_point_scale(draw_objcoord *to,
                      draw_objcoord *from, draw_objcoord *org);

/* Set a numeric field in a dbox fo a double */
extern void draw_setfield(dbox d, int field, double n);

/* Widen a box by a given amount */
extern void draw_widen_box(draw_bboxtyp *box, int xwiden, int ywiden);

/* Scale a box by a given factor */
extern void draw_box_scale(draw_bboxtyp *to, draw_bboxtyp *from,
    double factor);

/* Scale a box by a given factor, and add a shift */
/* After scaling and shifting, divifes coordinates by 256 */
extern void draw_box_scale_shift(draw_bboxtyp *to, draw_bboxtyp *from,
                          double factor, draw_objcoord *shift);

#if TRACE
  /*Splatter the whole database all over the screen.*/
  extern void draw_trace_db (diagrec *);
#else
  #define draw_trace_db(diag) ((void) 0)
#endif

#if TRACE
  #define FLEX_ALLOC(flex_ptr, n) \
    (ftracef0 ("flex_alloc\n"), flex_alloc(flex_ptr, n))
  #define FLEX_FREE(flex_ptr) \
    (ftracef0 ("flex_free\n"), flex_free (flex_ptr))
  #define FLEX_SIZE(flex_ptr) \
    (ftracef0 ("flex_size\n"), flex_size (flex_ptr))
  #define FLEX_EXTEND(flex_ptr, int) \
    (ftracef0 ("flex_extend\n"), flex_extend (flex_ptr, int))
  #define FLEX_MIDEXTEND(flex_ptr, at, by) \
    (ftracef0 ("flex_midextend\n"), flex_midextend(flex_ptr, at, by))
  #define FLEX_INIT() \
    (ftracef0 ("flex_init\n"), flex_init ())
#else
  #define FLEX_ALLOC     flex_alloc
  #define FLEX_FREE      flex_free
  #define FLEX_SIZE      flex_size
  #define FLEX_EXTEND    flex_extend
  #define FLEX_MIDEXTEND flex_midextend
  #define FLEX_INIT      flex_init
#endif
