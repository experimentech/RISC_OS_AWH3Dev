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
 * Title: dbox.h
 * Purpose: Creation/deletion/manipulation of dialogue boxes.
 *
 */

/* 
 * It is important to note that the structure of your dialogue templates is
 * an integral part of your program. Always use symbolic names for templates
 * and for fields and action buttons within them.  Templates for the
 * dialogue boxes can be loaded using the template module in this library
 *
 */

/* 
 * See separate documentation for how to use the RISC OS Template Editor
 * in conjunction with this interface. 
 */

#ifndef __dbox_h
#define __dbox_h

#ifndef BOOL
#define BOOL int
#define TRUE 1
#define FALSE 0
#endif


/* ------------------------------ dbox ------------------------------------
 * a dbox is an abstract dialogue box handle
 *
 */

typedef struct dbox__str *dbox;



/* ********************** Creation, Deletion functions ***************** */


/* ------------------------------ dbox_new ------------------------------
 * Description:   Builds a dialogue box from a named template 
 *                Template editor (FormEd) may have been used to create
 *                this template in the "Templates" file for the application.
 *
 * Parameters:    char *name -- template name (from templates previously
 *                              read in by template_init), from which to
 *                              construct dialogue box. Name is as given
 *                              when using FormEd to create template
 * Returns:       On successful completion, pointer to a dialogue box
 *                structure otherwise null (eg. when not enough space).
 * Other Info:    This only creates a structure. It doesn't display anything!
 *                *However* it does register the dialogue box as an active 
 *                window with the window manager.
 */

dbox dbox_new(char *name);


/* ------------------------------ dbox_dispose ----------------------------
 * Description:   Disposes of dialogue box structure.
 *
 * Parameters:    dbox* -- pointer to pointer to a dialogue box structure
 * Returns:       void.
 * Other Info:    This also has the side-efffect of hiding the dialogue box,
 *                so that it no longer appears on the screen. It also
 *                "un-registers" it as an active window with the
 *                window manager.
 */

void dbox_dispose(dbox*);



/* *************************** Display functions ************************ */

/* ----------------------------- dbox_show --------------------------------
 * Description:   Displays given dialogue box on the screen.
 *
 * Parameters:    dbox -- dialogue box to be displayed
 *                        (typically created by dbox_new)
 * Returns:       void.
 * Other Info:    Typically used when dialogue box is from a submenu
 *                so that it disappears when the menu is closed. If called
 *                when dialogue box is showing then no effect. The show will
 *                occur near the last menu selection or last caret setting
 *                (whichever is most recent).
 */  

void dbox_show(dbox);


/* ----------------------------dbox_showstatic ----------------------------
 * Description:   Displays given dialogue box on the screen, and leaves it
 *                there, until explicitly closed.
 *
 * Parameters:    dbox -- dialogue box to be displayed
 *                        (typically created by dbox_new)
 * Returns:       void.
 * Other Info:    typically, not used from menu selection, because it will
 *                persist longer than the menu (otherwise same as dbox_show).
 */

void dbox_showstatic(dbox);


/* ----------------------------- dbox_hide --------------------------------
 * Description:   Hides a previously displayed dialogue box.
 * 
 * Parameters:    dbox -- dialogue box to be hidden
 * Returns:       void.
 * Other Info:    Note that this does not release any storage. It just
 *                hides the dialogue box. If called when dialogue box  is
 *                already hidden, then no effect.
 */

void dbox_hide(dbox);




/* ***************************** dbox Fields. *************************** */

/* A dbox has a number of fields, labelled from 0. There are the following
 * distinct field types:
 *
 * "action" fields. Mouse clicks here are communicated to the client. The 
 * fields are usually labelled "go", "quit", etc. Set/GetField apply to the
 * label on the field, although this is usually set up in the template.
 *
 * "output" fields. These display a message to the user, using SetField.
 *  Mouse clicks etc. have no effect.
 *
 * "input" fields. The user can type into these, and simple local editing is
 * provided. Set/GetField can be used on the textual value, or 
 * Set/GetNumeric if the user should type in numeric values.
 *
 * "on/off" fields. The user can click on these to display their on/off 
 * status. They are always "off" when the dbox is first created. The 
 * template editor can set up mutually exclusive sets of these at will. 
 * Set/GetField apply to the label on this field, Set/GetNumeric 
 * set/get 1 (on) and 0 (off) values.
 *
 */

/* ---------------------- dbox_field / dbox_fieldtype --------------------
 * type dbox_field values are field numbers within a dbox
 * type dbox_fieldtype values indicate what sort a field is
 *                          (ie. action, output, input, on/off)
 *
 */
 
typedef int dbox_field; 

typedef enum {
               dbox_FACTION, dbox_FOUTPUT, dbox_FINPUT, dbox_FONOFF
} dbox_fieldtype;


/* -------------------------- dbox_setfield -------------------------------
 * Description:   Sets the given field, within the given dialogue box, to 
 *                the given text value.
 *
 * Parameters:    dbox -- the chosen dialogue box
 *                dbox_field -- chosen field number
 *                char* -- text to be displayed in field
 * Returns:       void.
 * Other Info:    if applied to non-text field then no effect
 *                if field is an indirected text icon then the text length
 *                is limited by the size value used when setting up the
 *                template in the template editor. Any longer text will be
 *                truncated to this length.
 *                otherwise text is truncated to 12 chars (11 text + 1 null)
 *                if dbox is currently showing, change is immediately 
 *                visible.
 *                
 */

void dbox_setfield(dbox, dbox_field, char*);


/* ---------------------------- dbox_getfield ------------------------------
 * Description:   Puts the current contents of the chosen text field into
 *                buffer, whose size is given as third parameter
 *
 * Parameters:    dbox -- the chosen dialogue box
 *                dbox_field -- the chosen field number
 *                char *buffer -- buffer to be used
 *                int size -- size of buffer
 * Returns:       void.
 * Other Info:    if applied to non-text field then null string put in buffer
 *                if the length of the chosen field (plus null-terminator)
 *                is larger than the buffer, then result will be truncated.
 */

void dbox_getfield(dbox, dbox_field, char *buffer, int size);


/* ---------------------------- dbox_setnumeric ----------------------------
 * Description:   Sets the given field, in the given dbox, to the given
 *                integer value.
 *
 * Parameters:    dbox -- the chosen dialogue box
 *                dbox_field -- the chosen field number
 *                int -- field's contents will be set to this value
 * Returns:       void.
 * Other Info:    if field is input/output, then the integer value is
 *                converted to a string and displayed in the field
 *                if field is of type "action" or "on/off" then a non-zero
 *                integer value "selects" this field; zero "de-selects".
 * 
 */

void dbox_setnumeric(dbox, dbox_field, int);


/* ---------------------------- dbox_getnumeric ----------------------------
 * Description:   Gets the integer value held in the chosen field of the
 *                chosen dbox.
 * 
 * Parameters:    dbox -- the chosen dialogue box
 *                dbox_field -- the chosen field number
 * Returns:       integer value held in chosen field
 * Other Info:    if the field is of type "on/off" then return value of 0
 *                means "off", 1 means "on"
 *                otherwise return value is integer equivalent of field
 *                contents.
 *
 */

int dbox_getnumeric(dbox, dbox_field);


/* --------------------------- dbox_fadefield ------------------------------
 * Description:   Makes a field unselectable (ie. faded by WIMP).
 *
 * Parameters:    dbox d -- the dialogue box in which field resides
 *                dbox_field f -- the field to be faded.
 * Returns:       void.
 * Other Info:    Fading an already faded field has no effect.
 *
 */

void dbox_fadefield(dbox d, dbox_field f);


/* --------------------------- dbox_unfadefield ----------------------------
 * Description:   Makes a field selectable (ie "unfades" it).
 *
 * Parameters:    dbox d -- the dialogue box in which field resides
 *                dbox_field f -- the field to be unfaded.
 * Returns:       void.
 * Other Info:    Unfading an already selectable field has no effect
 *
 */

void dbox_unfadefield(dbox d, dbox_field f);


/* --------------------------- dbox_hidefield ------------------------------
 * Description:   Makes a field hidden (ie. deleted by WIMP).
 *
 * Parameters:    dbox d -- the dialogue box in which field resides
 *                dbox_field f -- the field to be hidden.
 * Returns:       void.
 * Other Info:    Hiding an already hidden field has no effect.
 *
 */

void dbox_hidefield(dbox d, dbox_field f);


/* --------------------------- dbox_unhidefield ----------------------------
 * Description:   Makes a field shown again (ie "unhides" it).
 *
 * Parameters:    dbox d -- the dialogue box in which field resides
 *                dbox_field f -- the field to be unhidden.
 * Returns:       void.
 * Other Info:    Unhiding an already shown field has no effect
 *
 */

void dbox_unhidefield(dbox d, dbox_field f);


/* ************************ Events from dboxes. ************************ */

/* A dbox acts as an input device: a stream of characters comes from it
 * somewhat like a keyboard, and an up-call can be arranged when input is
 * waiting. 
 */

#define dbox_CLOSE ((dbox_field) -1)

/* dboxes may have a "close" button that is separate from their action
 * buttons, usually in the header of the window. If this is pressed then 
 * CLOSE is returned, this should lead to the dbox being invisible. If the
 * dbox represents a particular pending operation then the operation should 
 * be cancelled. 
 */

/* ------------------------------ dbox_get ---------------------------------
 * Description:   Tells caller which action field has been activated in the
 *                chosen dialogue box
 *
 * Parameters:    dbox -- the chosen dialogue box
 * Returns:       field number of activated field
 * Other Info:    This should only be called from an event handler
 *                (since this is the only situation where it makes sense).
 *
 */ 

dbox_field dbox_get(dbox d);


/* ------------------------------ dbox_read ---------------------------------
 * Description:   Tells caller which action field has been activated in the
 *                chosen dialogue box. Does not cancel the event.
 *
 * Parameters:    dbox -- the chosen dialogue box
 * Returns:       field number of activated field
 * Other Info:    This should only be called from an event handler
 *                (since this is the only situation where it makes sense).
 *
 */ 

dbox_field dbox_read(dbox d);


/* ------------------------ dbox_eventhandler ------------------------------
 * Description:   Register an event handler function for the given dialogue 
 *                box.
 *
 * Parameters:    dbox -- the chosen dialogue box
 *                dbox_handler_proc -- name of handler function
 *                void *handle -- user-defined handle
 * Returns:       void.
 * Other Info:    When a field of the given dialogue box has been activated
 *                the user-supplied handler function is called.
 *                The handler should be defined in the form:
 *                           void foo (dbox d, void *handle)
 *                When called the function "foo" will be passed the relevant
 *                dialogue box, and its user-defined handle. A typical action
 *                in "foo" would be to call dbox_get to determine which
 *                field was activated. If handler==0 then no function is
 *                installed as a handler (and any existing handler is
 *                "un-registered".
 *
 */

typedef void (*dbox_handler_proc)(dbox, void *handle);

void dbox_eventhandler(dbox, dbox_handler_proc, void* handle);


/* -------------------------- dbox_raweventhandler -------------------------
 * Description:   Register a "raw" event handler for the given dialogue box.
 *
 * Parameters:    dbox -- the given dialogue box
 *                dbox_raw_handler_proc proc -- handler function for event
 *                void *handle -- user-defined handle.
 * Returns:       void.
 * Other Info:    This registers a function which will be passed "unvetted"
 *                window events. Under the window manager in RISC OS, the
 *                event will be a wimp_eventstr* (see Wimp module). The
 *                supplied handler function should return true if it 
 *                processed the event; if it returns false, then the event
 *                will be passed on to any event handler defined using
 *                dbox_eventhandler() as above. The form of the handler's
 *                function header is:
 *                          BOOL func (dbox d, void *event, void *handle).
 *
 */
 
typedef BOOL (*dbox_raw_handler_proc)(dbox, void *event, void *handle);

void dbox_raw_eventhandler(dbox, dbox_raw_handler_proc, void *handle);



/* dboxes are often used to fill in the details of a pending operation. In
this case a down-call driven interface to the entire interaction is often
convenient. The following facilties aid this form of use. */


/* -------------------------- dbox_fillin -------------------------------
 * Description:   Process events until a field in the given dialogue box
 *                has been activated.
 *
 * Parameters:    dbox d -- the given dialogue box
 * Returns:       field number of activated field.
 * Other Info:    Handling of harmful events, same as dbox_popup (see below).
 *                On each call to dbox_fillin, the caret is set to the end of the
 *                lowest numbered writeable icon
 */

dbox_field dbox_fillin(dbox d);


/* -------------------------- dbox_fillin_fixedcaret --------------------
 * Description:   Process events until a field in the given dialogue box
 *                has been activated.
 *
 * Parameters:    dbox d -- the given dialogue box
 * Returns:       field number of activated field.
 * Other Info:    Same as dbox_fillin, except caret is not set to end of lowest
 *                numbered writeable icon
 */

dbox_field dbox_fillin_fixedcaret(dbox d);



/* ------------------------------ dbox_popup -------------------------------
 * Description:   Build a dialogue box, from a named template, assign message
 *                to field 1, do a dbox_fillin, destroy the dialogue box,
 *                and return the number of the activated field.
 *
 * Parameters:    char *name -- template name for dialogue box
 *                char *message -- message to be displayed in field 1
 * Returns:       field number of activated field
 * Other Info:    "harmful" events are those which could cause the dialogue 
 *                to fail (eg. keystrokes, mouse clicks). These events will 
 *                cause the dialogue box to receive a CLOSE event.
 *
 */

dbox_field dbox_popup(char *name, char *message);


/* ------------------------------ dbox_persist -----------------------------
 * Description:   When dbox_fillin has returned an action event, this
 *                function returns true if the user wishes the action to
 *                be performed, but the dialogue box to remain.
 *
 * Parameters:    void.
 * Returns:       BOOL -- does user want dbox to remain on screen?
 * Other Info:    Current implementation returns true when user has clicked
 *                Adjust. Caller should continue round fill-in
 *                loop if return value is true (ie. don't destroy dbox).
 *
 */

BOOL dbox_persist(void);


/* ***************************** System hook. **************************** */

/* --------------------------- dbox_syshandle ------------------------------
 * Description:   Allows the caller to get a handle on the window associated
 *                with the given dialogue box.
 *
 * Parameters:    dbox -- the given dialogue box
 * Returns:       window handle of dialogue box (this is a wimp_w under the
 *                RISC OS window manager).
 * Other Info:    This could be used to hang a menu off a dialogue box, or
 *                to "customise" the dialogue box in some way. Note that
 *                dbox_dispose will also dispose of any such attached menus.
 *     
 */

int dbox_syshandle(dbox);


/* ************************** Initialisation **************************** */

/* ---------------------------- dbox_init ----------------------------------
 * Description:   Prepare for use of dialogue boxes from templates
 *
 * Parameters:    void
 * Returns:       void
 * Other Info:    This function must be called ONCE before any dbox functions
 *                are used. You should call template_init() before this
 *                function.
 *
 */

void dbox_init(void);

#endif

/* end dbox.h */
