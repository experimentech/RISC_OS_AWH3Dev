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
 * Title: baricon.h
 * Purpose: Support placing of an icon on the icon bar.
 *
 */

#ifndef __baricon_h
#define __baricon_h

# ifndef __wimp_h
# include "wimp.h"
# endif

/* -------------------------baricon_clickproc---------------------- */

/* baricon_clickproc is the type of a function to be called when Select 
 * is clicked.
 */

typedef void (*baricon_clickproc)(wimp_i);

/* ----------------------------- baricon -----------------------------------
 * Description:   Installs the named sprite as an icon on the right of the 
 *                icon bar and registers a function to be called when Select 
 *                is clicked.
 *
 * Parameters:    char *spritename     -- name of sprite to be used
 *                int spritearea       -- area in which sprite is held
 *                baricon_clickproc p  -- pointer to function to be
 *                                        called on left mouse click
 * Returns:       the icon number of the installed icon (of type wimp_i).
 *                This will be passed to function "p" on left mouse click.
 * Other info:    For details of installing a menu handler for this icon
 *                see event_attachmenu().
 */ 

wimp_i baricon(char *spritename, int spritearea, baricon_clickproc p);

/* -------------------------------- baricon_left --------------------------
 * Description:   Installs the named sprite as an icon on the left of the
 *                icon bar and regsiters a function to be called when Select
 *                is clicked.
 *
 * Parameters:    As for baricon, above.
 * Returns:       As for baricon, above.
 * Other info:    As for baricon, above.
 */

wimp_i baricon_left(char *spritename, int spritearea, baricon_clickproc p);

/* ----------------------------- baricon_textandsprite --------------------
 * Description:   Installs the named sprite as an icon on the right of the 
 *                icon bar with some given text below it, and registers a 
 *                function to be called when Select is clicked.  
 *
 * Parameters:    char *spritename     -- name of sprite to be used
 *                char *text           -- text to appear under sprite
 *                int bufflen          -- length of text buffer
 *                int spritearea       -- area in which sprite is held
 *                baricon_clickproc p  -- pointer to function to be
 *                                        called on left mouse click
 * Returns:       the icon number of the installed icon (of type wimp_i).
 *                This will be passed to function "p" on left mouse click.
 * Other info:    For details of installing a menu handler for this icon
 *                see event_attachmenu().
 *                The width of the icon is taken as the greater of bufflen
 *                system font characters and the width of the sprite used.
 *
 */ 

wimp_i baricon_textandsprite(char *spritename, char *text,
                      int bufflen, int spritearea, baricon_clickproc p);

/* -------------------------- baricon_textandsprite_left ------------------
 * Description:   Installs the named sprite as an icon on the right of the 
 *                icon bar with some given text below it, and registers a 
 *                function to be called when Select is clicked.  
 *
 * Parameters:    char *spritename     -- name of sprite to be used
 *                char *text           -- text to appear under sprite
 *                int bufflen          -- length of text buffer
 *                int spritearea       -- area in which sprite is held
 *                baricon_clickproc p  -- pointer to function to be
 *                                        called on left mouse click
 * Returns:       the icon number of the installed icon (of type wimp_i).
 *                This will be passed to function "p" on left mouse click.
 * Other info:    For details of installing a menu handler for this icon
 *                see event_attachmenu().
 *                The width of the icon is taken as the greater of bufflen
 *                system font characters and the width of the sprite used.
 *
 */ 

wimp_i baricon_textandsprite_left(char *spritename, char *text,
                      int bufflen, int spritearea, baricon_clickproc p);


/* ----------------------------- baricon_newsprite -------------------------
 * Description:   Changes the sprite used on the icon bar
 *
 * Parameters:    char *newsprite  -- name of new sprite to be used
 *
 * Returns:       the icon number of the installed icon sprite
 * Other Info:    Newsprite must be held in the same sprite area as
 *                the sprite used in baricon()
 *
 */

wimp_i baricon_newsprite(char *newsprite);

#endif

/* end baricon.h */
