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
/****************************************************************************
 * This source file was written by Acorn Computers Limited. It is part of   *
 * the RISCOS library for writing applications in C for RISC OS. It may be  *
 * used freely in the creation of programs for Archimedes. It should be     *
 * used with Acorn's C Compiler Release 3 or later.                         *
 *                                                                          *
 ***************************************************************************/

/* 
 * Title: txtedit.h
 * Purpose: Text editing facilities.
 *
 */

# ifndef __txtedit_h
# define __txtedit_h

# ifndef __txt_h
# include "txt.h"
# endif

# ifndef __typdat_h
# include "typdat.h"
# endif

#ifndef __menu_h
#include "menu.h"
#endif

#ifndef BOOL
#define BOOL int
#define TRUE 1
#define FALSE 0
#endif

/****************************** DATA TYPES *********************************/

typedef enum
  {
    txtedit_CHARSEL = 1, txtedit_WORDSEL = 2, txtedit_LINESEL = 4

  } txtedit_seltype;

typedef struct txtedit_state
  {
    txt             t;
    txt_marker      selpivot;       /* used in mouse op calculations */
    txtedit_seltype seltype;        /* used in mouse op calculations */
    int             selectrecent;   /* used in mouse op calculations */
#if FALSE
    int             selectctl;      /* used in mouse op calculations */
#endif
    char            filename[256];
    typdat          ty;
    struct txtedit_state *next;     /* chain of all of them. */
    BOOL            overwrite;
    BOOL            wordtab;
    BOOL            wordwrap;
  } txtedit_state;

typedef BOOL (*txtedit_update_handler)(char *, txtedit_state *, void *);
typedef void (*txtedit_close_handler)(char *, txtedit_state *, void *);
typedef BOOL (*txtedit_save_handler)(char *, txtedit_state *, void *);
typedef void (*txtedit_shutdown_handler)(void *);
typedef void (*txtedit_undofail_handler)(char *, txtedit_state *, void *);
typedef void (*txtedit_open_handler)(char *, txtedit_state *, void *);

/**************************** INTERFACE FUNCTIONS *************************/


/* --------------------------- txtedit_install -----------------------------
 * Description:   Installs an event handler for the txt t, thus making it
 *                an editable text.
 *
 * Parameters:    txt t -- the text object (created via txt_new)
 * Returns:       A pointer to the resulting txtedit_state.
 * Other Info:    none.
 *
 */

txtedit_state *txtedit_install(txt t);


/* ----------------------------- txtedit_new -------------------------------
 * Description:   Creates a new text object, loads the given file into it
 *                and the text can now be edited.
 *
 * Parameters:    char *filename -- the file to be loaded.
 *                int filetype -- filetype to be given if null filename
 * Returns:       a pointer to the txtedit_state for this text.
 * Other Info:    If the file cannot be found, then 0 is returned as a 
 *                result, and no text is created. If "filename" is a null
 *                pointer, then an editor window with no given file name
 *                will be constructed. If the file is already being edited,
 *                then a pointer to the existing txtedit_state is returned.
 *
 */

txtedit_state *txtedit_new(char *filename, int filetype);


/* ---------------------------- txtedit_dispose ----------------------------
 * Description:   Destroys the given text being edited.
 *
 * Parameters:    txtedit_state *s -- the text to be destroyed.
 * Returns:       void.
 * Other Info:    Note: this will ask no questions of the user before
 *                destroying the text.
 *
 */
 
void txtedit_dispose(txtedit_state *s);


/* --------------------------- txtedit_mayquit -----------------------------
 * Description:   Check if we may safely quit editing.
 *
 * Parameters:    void.
 * Returns:       TRUE if we may safely quit, otherwise FALSE.
 * Other Info:    If a text is being edited, then a dialogue box is displayed
 *                asking the user if he really wants to quit.
 *                This calls dboxquery(), and therefore requires the 
 *                template "query" as described in dboxquery.h.
 *
 */

BOOL txtedit_mayquit(void);


/* ----------------------------- txtedit_prequit ---------------------------
 * Description:   Deal with a PREQUIT message from the task manager.
 *
 * Parameters:    void.
 * Returns:       void.
 * Other Info:    Calls txtedit_mayquit(), to see if we may quit, if text
 *                is being edited. If user replies that we may quit, then
 *                all texts are disposed of, and this function sends an
 *                acknowledgement to the task manager.
 *
 */

void txtedit_prequit(void);


/* ---------------------------- txtedit_menu -------------------------------
 * Description:   Sets up a menu structure for the text being edited,
 *                tailored to its current state.
 *
 * Parameters:    txtedit_state * s -- the text's current state.
 * Returns:       a pointer to an appropriately formed menu structure
 * Other Info:    The menu created will have the same form as that displayed
 *                when mouse menu button is clicked on an !Edit window.
 *                (For !Edit version 1.00).
 *                Entries in the menu are set according to the supplied
 *                txtedit_state.
 */

menu txtedit_menu(txtedit_state *s);


/*------------------------------ txtedit_menuevent -------------------------
 * Description:   Apply a given menu hit to a given text.
 *
 * Parameters:    txtedit_state *s -- the text to which hit should be applied
 *                char *hit -- a menu hit string.
 * Returns:       void.
 * Other Info:    This can be called from a menu event handler.
 *
 */
    
void txtedit_menuevent(txtedit_state *s, char *hit);


/* --------------------------- txtedit_doimport ----------------------------
 * Description:   Import data into the specified txtedit object, from a file
 *                of a given type.
 *
 * Parameters:    txtedit_state *s -- the text object
 *                int filetype -- type of the file
 *                int estsize -- file's estimated size.
 * Returns:       TRUE if import completed successfully.
 * Other Info:    none.
 *
 */

BOOL txtedit_doimport(txtedit_state *s, int filetype, int estsize);


/* ------------------------- txtedit_doinsertfile --------------------------
 * Description:   Inserts a named file in a given text object.
 *
 * Parameters:    txtedit_state *s -- the text object
 *                char *filename -- the given file
 *                BOOL replaceifwasnull -- if set to TRUE then the text
 *                                         object will be considred to have
 *                                         come from "filename", ie. window
 *                                         title is updated.
 *
 * Returns:       void.
 * Other Info:    none.
 *
 */

void txtedit_doinsertfile(txtedit_state *s, char *filename, BOOL replaceifwasnull);

/* ------------------------ txtedit_settexttitle --------------------------
 * Description:   Updates the text window titles to reflect the state of
 *                the specified text object
 *
 * Parameters:    txtedit_state *s -- the text object
 * Returns:       void.
 * Other Info:    none.
 *
 */

void txtedit_settexttitle(txtedit_state *s);

/* ------------------------ txtedit_register_update_handler ---------------
 * Description:   Register a handler to be called when a text window is 
 *                modified
 *
 * Parameters:    txtedit_handler h -- the handler function
 *                void *handle      -- handle to be passed to the function
 * Returns:       previous handler
 * Other Info:    This routine will be called whenever a window's title bar
 *                is redrawn, and the text in the window has been modified.
 *                Note: this is not just called when the '*' first appears 
 *                in a window's title bar, but every time the title bar of a
 *                modified text window is redrawn (eg. when the filename
 *                changes or wordwrap is turned on/off etc).
 *                The handler function will be passed:
 *                       i) the filename for the window title
 *                      ii) the address of this 'txtedit_state'
 *                     iii) the handle registered with this function
 *                If the handler returns FALSE, then the last modification
 *                will be undone.  This is only possible if the modification
 *                is not greater than ~5kb.
 *                Calling with h == 0 removes the handler.
 *
 */

txtedit_update_handler txtedit_register_update_handler(txtedit_update_handler h, void *handle);


/* ------------------------ txtedit_register_save_handler ------------------
 * Description:   Register a handler to be called when a text window is 
 *                saved
 *
 * Parameters:    txtedit_handler h -- the handler function
 *                void *handle      -- handle to be passed to the function
 * Returns:       previous handler
 * Other Info:    This routine will be called whenever a text window is saved
 *                to file (NOT via RAM transfer).
 *                The handler function will be passed:
 *                       i) the filename for the window title
 *                      ii) the address of this 'txtedit_state'
 *                     iii) the handle registered with this function
 *                Calling with h == 0 removes the handler.
 *                Returning FALSE from your handler will abort the save
 *                operation.
 *
 */

txtedit_save_handler txtedit_register_save_handler(txtedit_save_handler h, 
                                                   void *handle);


/* ------------------------ txtedit_register_close_handler ----------------
 * Description:   Register a handler to be called when a modified text 
 *                window is closed
 *
 * Parameters:    txtedit_handler h -- the handler function
 *                void *handle      -- handle to be passed to the function
 * Returns:       previous handler
 * Other Info:    This routine will be called whenever a text
 *                window is closed.
 *                The handler function will be passed:
 *                       i) the filename for the window title
 *                      ii) the address of this 'txtedit_state'
 *                     iii) the handle registered with this function
 *                Calling with h == 0 removes the handler.
 *
 */

txtedit_close_handler txtedit_register_close_handler(txtedit_close_handler h,
                                                     void *handle);


/* ------------------------ txtedit_register_shutdown_handler --------------
 * Description:   Register a handler to be called when txtedit_prequit() is
 *                called. 
 *
 * Parameters:    txtedit_handler h -- the handler function
 *                void *handle      -- handle to be passed to the function
 * Returns:       previous handler
 * Other Info:    This routine will be called whenever txtedit_prequit() is
 *                called, and the user answers "yes" when asked if he really
 *                wants to quit edit, or no files have been modified.
 *                The handler function will be passed the handle
 *                registered with this function
 *                Calling with h == 0 removes the handler.
 *
 */

txtedit_shutdown_handler txtedit_register_shutdown_handler(txtedit_shutdown_handler h, void *handle);


/* ------------------------ txtedit_register_undofail_handler --------------
 * Description:   Register a handler to be called when your update_handler
 *                returned FALSE, and the undo buffer overflowed. 
 *
 * Parameters:    txtedit_handler h -- the handler function
 *                void *handle      -- handle to be passed to the function
 * Returns:       previous handler
 * Other Info:    This will be called when the modification made to an
 *                edited file cannot be undone (only in conjunction with
 *                an update handler).
 *                The handler function will be passed:
 *                       i) the filename for the window title
 *                      ii) the address of this 'txtedit_state'
 *                     iii) the handle registered with this function
 *                Calling with h == 0 removes the handler.
 *
 */

txtedit_undofail_handler txtedit_register_undofail_handler(txtedit_undofail_handler h, void *handle);


/* -------------------------- txtedit_register_open_handler -------------------
 * Description:   Register a handler to be called when a new txtedit_state is
 *                created. 
 *
 * Parameters:    txtedit_handler h -- the handler function
 *                void *handle      -- handle to be passed to the function
 * Returns:       previous handler
 * Other Info:    The handler function will be passed:
 *                       i) the filename for the window title
 *                      ii) the address of this 'txtedit_state'
 *                     iii) the handle registered with this function
 *                Calling with h == 0 removes the handler.
 *
 */

txtedit_open_handler txtedit_register_open_handler(txtedit_open_handler h, void *handle);


/* ---------------------------- txtedit_getstates --------------------------
 * Description:   Get a pointer to the list of current txtedit_states
 *
 * Parameters:    void.
 * Returns:       Pointer to the list of txtedit_states
 * Other Info:    The txtedit part of RISC_OSlib keeps a list of all
 *                txtedit_states created (via txtedit_new). This function
 *                allows access to this list
 *
 */

txtedit_state *txtedit_getstates(void);

/* ---------------------------- txtedit_setBASICaddresses ------------------
 * Description:   Initialises the internal pointers to BASIC's tokenising
 *                and detokenising routines. This is necessary before the
 *                txtedit module can tokenise and detokenise BASIC.
 *
 * Parameters:    int tokenise   -- the address of BASIC's tokeniser
 *                int detokenise -- the address of BASIC's detokeniser
 * Returns:       void.
 * Other Info:    These two addresses can be obtained from the short BASIC
 *                program inside !Edit, which sets two system variables.
 *
 */

void txtedit_setBASICaddresses(int tokenise, int detokenise);

/* ---------------------------- txtedit_setBASICstrip ----------------------
 * Description:   Sets the internal flag to indicate whether or not line
 *                numbers should be stripped from BASIC files being loaded.
 *
 * Parameters:    BOOL strip -- TRUE if line numbers should be stripped,
 *                              else FALSE
 * Returns:       void.
 * Other Info:    none.
 *
 */

void txtedit_setBASICstrip(BOOL strip);

/* ---------------------------- txtedit_setBASICincrement ------------------
 * Description:   Sets the increment to be used when creating line numbers.
 *
 * Parameters:    int increment
 * Returns:       void.
 * Other Info:    none.
 *
 */

void txtedit_setBASICincrement(int increment);

/* ---------------------------- txtedit_init -------------------------------
 * Description:   Initialise the txtedit module of the library
 *
 * Parameters:    void.
 * Returns:       void.
 * Other Info:    none.
 *
 */

void txtedit_init(void);

#endif

/* end txtedit.h */
