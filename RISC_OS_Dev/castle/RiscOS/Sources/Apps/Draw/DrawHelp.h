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
/* -> h.DrawHelp
 *
 * Header for help functions in Draw
 *
 * Author:  Richard Manby, David Elworthy
 * Version: 0.11
 * History: 0.10 - 12 June 1989 - header added. Old code weeded.
 *          0.11 - 19 Sept 1989 - draw_help_reply added.
 *
 */

void draw_help_reply(wimp_msgstr *msg, char *line1, char *line2);
void draw_help_helpmessage(wimp_eventstr *e, diagrec *diag);
void draw_help_helptoolbox(wimp_eventstr *e);