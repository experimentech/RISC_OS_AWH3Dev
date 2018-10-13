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

/* Title:   xferrecv.h
 * Purpose: general purpose import of data by dragging icon
 *
 */

#ifndef __xferrecv_h
#define __xferrecv_h

#ifndef BOOL
#define BOOL int
#define TRUE 1
#define FALSE 0
#endif


/* -------------------------- xferrecv_checkinsert -------------------------
 * Description:   Set up the acknowledge message for a MDATAOPEN or MDATALOAD
 *                and get filename to load from.
 *
 * Parameters:    char **filename -- returned pointer to filename
 * Returns:       the file's type (eg. 0x0fff for !Edit)
 * Other Info:    This function checks to see if the last wimp event was a 
 *                request to import a file. If so it returns file type and
 *                a pointer to file's name is put into *filename. If not
 *                it returns -1.   
 *
 */

int xferrecv_checkinsert(char **filename);


/* --------------------------- xferrecv_insertfileok -----------------------
 * Description:   Deletes scrap file (if used for transfer), and sends
 *                acknowledgement of MDATALOAD message.
 *
 * Parameters:    void
 * Returns:       void.
 * Other Info:    none.
 *
 */

void xferrecv_insertfileok(void);


/* --------------------------- xferrecv_checkprint -------------------------
 * Description:   Set up acknowledge message to a MPrintTypeOdd message
 *                and get file name to print.
 *
 * Parameters:    char **filename -- returned pointer to filename
 * Returns:       The file's type (eg. 0x0fff for !Edit).
 * Other Info:    Application can either print file directly or convert it to
 *                <Printer$Temp> for printing by the printer application.
 *
 */

int xferrecv_checkprint(char **filename);


/* --------------------------- xferrecv_printfileok ------------------------
 * Description:   Send an acknowledgement back to printer application. If
 *                file sent to <Printer$Temp> then this also fills in file
 *                type in message.
 *
 * Parameters:    int type -- type of file sent to <Printer$Temp> 
 *                            (eg. 0x0fff for !edit)
 * Returns:       void.
 * Other Info:    none.
 *
 */

void xferrecv_printfileok(int type);


/* ---------------------------- xferrecv_checkimport -----------------------
 * Description:   Set up acknowledgement message to a MDATASAVE message.
 *
 * Parameters:    int *estsize -- sender's estimate of file size
 * Returns:       File type.
 * Other Info:    none.
 *
 */

int xferrecv_checkimport(int *estsize);


/* ------------------------- xferrecv_buffer_processor ---------------------
 * Description:   This is a typedef for the caller-supplied function
 *                to empty a full buffer during data transfer.
 *
 * Parameters:    char **buffer -- new buffer to be used
 *                int *size -- updated size
 * Returns:       return FALSE if unable to empty buffer or create new one.
 * Other Info:    This is the function (supplied by application,) which will
 *                be called when buffer is full. It should empty the current
 *                buffer, or create more space and modify size accordingly
 *                or return FALSE. *buffer and *size are the current buffer
 *                and its size on function entry.
 *
 */
 
typedef BOOL (*xferrecv_buffer_processor)(char **buffer, int *size);



/* ---------------------------- xferrecv_doimport --------------------------
 * Description:   Loads data into a buffer, and calls the caller-supplied
 *                function to empty the buffer when full.
 *
 * Parameters:    char *buf -- the buffer
 *                int size -- buffer's size
 *                xferrecv_buffer_processor -- caller-supplied function to
 *                                             be called when buffer full
 * Returns:       Number of bytes transferred on successful completion
 *                or -1 otherwise.
 * Other Info:    none.
 *
 */

int xferrecv_doimport(char *buf, int size, xferrecv_buffer_processor);



/* ---------------------- xferrecv_file_is_safe ----------------------------
 * Description:   Informs caller if file was received from a "safe" source
 *                (see below for definition of "safe").
 *
 * Parameters:    void
 * Returns:       true if file is safe.
 * Other Info:    "Safe" in this context means that the supplied filename
 *                will not change in the foreseeable future.
 *
 */

BOOL xferrecv_file_is_safe(void);



/* ---------------------- xferrecv_last_ref -------------------------------
 * Description:   Informs caller of the last wimp_sendmessage() reference
 *                when an xferrecv_doimport() fails and is now awaiting
 *                using <Wimp$Scrap> instead.
 *
 * Parameters:    void
 * Returns:       message reference.
 *
 */

int xferrecv_last_ref(void);

#endif

/* end xferrecv.h */
