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
/* -> h.DrawDXF
 *
 * Header for DXF functions in Draw
 *
 * Author:  David Elworthy
 * Version: 0.51
 * History: 0.50 - 12 June 1989 - header added. Old code weeded.
 *          0.51 - 29 June 1989 - name change, set options added.
 *
 */

BOOL draw_dxf_fetch_dxfFile(diagrec * diag, char * fileName, int length,
                            draw_objcoord *pt, BOOL viaRam);
BOOL draw_dxf_setOptions(void);