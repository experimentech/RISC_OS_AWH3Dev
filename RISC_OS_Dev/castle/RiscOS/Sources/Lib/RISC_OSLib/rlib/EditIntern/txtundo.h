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
/*
 * Title: h.txtundo
 * Purpose: Undo facilities for text objects
 * Author: W. Stoye
 * Status: system-independent
 * Requires:
 *   h.txt
 * History:
 *   13-Oct-87: started
 *   02-Mar-88: comments improved.
 *   08-Mar-88: WRS: txtundo_commit added.
 *   14-Mar-88: WRS: undoing of selection added.
 */

void txtundo_setbufsize(txt, int nbytes);
/* Every text object has an undo buffer within it. By default this is very
small, this call is necessary to make it larger. This buffer is used to
record all changes to the text in a form that allows the changes to be
reversed. */

void txtundo_separate_major_edits(txt);
/* This may be called between "major" edits, so that undoing can be done in
units that the user understands, rather than single moves, deletes and
inserts. Adjacent separators, without intermediate edits, will be ignored. */

void txtundo_purge_undo(txt);
/* Prevent undoing from going back beyond this point. This is useful if
the text object has been edited by direct access to txt_arraysegment, or if
for any other reason going back beyond this point is not reasonable. */

BOOL txtundo_suspend_undo(txt, BOOL);
/* Temporarily suspend (or resume) puts into the undo buffer. This is useful if
lots of edits are being implicitly being made by calling txt's internal routines
to achieve some overall much more simply expressed edit. The more simple
version can then be inserted manually rather than polluting the undo buffer
with all the intermediate steps. */

typedef enum {
  txtundo_MINOR,   /* successfully reversed a move/copy/delete */
  txtundo_MAJOR,   /* encountered a major edit separator */
  txtundo_RANOUT   /* coudn't do anything, it was too long ago and has
                    * been discarded, or there were no previous edits. */
} txtundo_result;

void txtundo_init(txt);
/* Prepare to start a sequence of undo operations. */

txtundo_result txtundo_undo(txt);
/* undo the last insert, delete, select or move operation. If successful the
inverse operation will be invoked on the text, further adding to the undo
buffer. A pointer to "current position" within the undo buffer is maintained,
so that subsequent calls to undo go further back into history. The pointer is
reset by a call to txtundo_init. No other edits to the text should occur
between a txtundo_init and subsequent undo/redo calls. */

txtundo_result txtundo_redo(txt);
/* Redo an operation caused by undo. The result concerns the operation that
will be processed by the next redo, this make it simple to contruct a loop
that redoes a major edit. */

/* Given a large enough undo buffer, undo/redo allow the client to move
at will between all past states of this text object. An operation will not be
undone unless its inverse will also fit in the undo buffer, so an undo
operation is always reversible. */

void txtundo_commit(txt);
/* At the end of a sequence of undos, this removes the ability to redo
the undos. In doing so it frees the space within the undo buffer required to
save the inverse operations. */

/* -------- Implementation Details. -------- */

/* The rest of this interface is only accessed within the implementation
of text objects. */

typedef struct txtundo__state *txtundo; /* abstract undo buffer state. */

txtundo txtundo_new(void); /* with small undo buffer. Will return
0 if not enough store. */

void txtundo_dispose(txtundo);

void txtundo_putbytes(txtundo, char*, int);
void txtundo_putnumber(txtundo, int);
void txtundo_putcode(txtundo, char);
/* The main editor buffer should use these in the following way:
  when deleting n chars:
    putbytes the chars themselves
    putnumber n
    putcode 'i'
  when inserting n chars:
    putnumber n
    putcode 'd'
  when moving from Index m to Index n:
    putnumber m
    putcode 'm'
  when setting the selection:
    putnumber index-of-old-start-of-selection
    putnumber index-of-old-end-of-selection
    putcode 'l'
  when toggling the case of the selection:
    putcode 't'
This can be done without regard for overflow etc.

Calling txtundo_putcode when not nested within any undo op on that
text object, has the additional effect of calling txtundo_init.
*/

void txtundo_pr(txtundo u);
/* For debugging purposes: print out a representation of the
undo buffer to the trace output stream. */

/* end */
