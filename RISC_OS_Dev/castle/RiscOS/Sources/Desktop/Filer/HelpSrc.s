; This source code in this file is licensed to You by Castle Technology
; Limited ("Castle") and its licensors on contractual terms and conditions
; ("Licence") which entitle you freely to modify and/or to distribute this
; source code subject to Your compliance with the terms of the Licence.
;
; This source code has been made available to You without any warranties
; whatsoever. Consequently, Your use, modification and distribution of this
; source code is entirely at Your own risk and neither Castle, its licensors
; nor any other person who has contributed to this source code shall be
; liable to You for any loss or damage which You may suffer as a result of
; Your use, modification or distribution of this source code.
;
; Full details of Your rights and obligations are set out in the Licence.
; You should have received a copy of the Licence with this source code file.
; If You have not received a copy, the text of the Licence is available
; online at www.castle-technology.co.uk/riscosbaselicence.htm
;
        SUBT    > <wini>arm.Filer.HelpSrc

        [ International_Help = 0

Filer_OpenDir_Help
        =       "*", TokenEscapeChar,Token0
        =       " may be used in the Desktop to open a directory viewer.", 13
        =       "Options are taken from the Filer's template and the user's",13
        =       "selections in the Filer's menu.",13
        =       "Switches:",13
        =       "-SmallIcons", 9, "Display small icons",13
        =       "-LargeIcons", 9, "Display large icons", 13
        =       "-FullInfo", 9, "Display full information", 13
        =       "-SortbyName", 9, "Display sorted by name", 13
        =       "-SortbyType", 9, "Display sorted by type", 13
        =       "-SortbyDate", 9, "Display sorted by date", 13
        =       "-SortbySize", 9, "Display sorted by size", 13
        =       "-ReverseSort", 9, "Sort in reverse order", 13
        =       "-NumericalSort", 9, "Sort digits in names as numbers", 13
        =       "Field names:", 13
        =       "-DIRectory", 9, "The full dirname", 13
        =       "-X0, -topleftx", 9, "The x-coordinate of the top left of", 13
        =       9, 9, 9, "directory viewer", 13
        =       "-Y1, -toplefty", 9, "The y-coordinate of the top left of", 13
        =       9, 9, 9, "directory viewer", 13
        =       "-Width", 9, 9, "The width of the viewer", 13
        =       "-Height", 9, 9, "The height of the viewer", 13
        =       "All numeric quantities are in OS units", 13
Filer_OpenDir_Syntax
        =       "Syntax: *"
        =       TokenEscapeChar,Token0
        =       " <full dirname> [<x> <y> [<width> <height>]] [<switches>]", 0

Filer_CloseDir_Help
        =       "*", TokenEscapeChar,Token0
        =       " may be used in the Desktop to close a directory viewer."
        =       13
Filer_CloseDir_Syntax
        =       "Syntax: *"
        =       TokenEscapeChar,Token0
        =       " <full dirname>", 0

Filer_Run_Help
        =       "*", TokenEscapeChar,Token0
        =       " is equivalent of double clicking on an object", 13
Filer_Run_Syntax
        =       "Syntax: *"
        =       TokenEscapeChar,Token0
        =       " [-Shift|-NoShift] <file>|<application>", 0

Filer_Boot_Help
        =       "*", TokenEscapeChar,Token0
        =       " boots the application specified", 13

Filer_Boot_Syntax
        =       "Syntax: *"
        =       TokenEscapeChar,Token0
        =       " <application>", 0

Filer_Truncation_Help
        =       "*", TokenEscapeChar,Token0
        =       " is used to set the width that long filenames are truncated to. ", 13

Filer_Truncation_Syntax
        =       "Syntax: *"
        =       TokenEscapeChar,Token0
        =       " [-LargeIconDisplay <number of pixels>]", 0

Filer_Options_Help
        =       "*", TokenEscapeChar,Token0
        =       " sets the default options for Filer operations.", 13
        =       "Switches:", 13
        =       "-ConfirmAll", 9, "Prompt for confirmation of all operations", 13
        =       "-ConfirmDeletes", 9, "Prompt for confirmation of deletes only", 13
        =       "-Verbose", 9, "Provide an information window during operations", 13
        =       "-Force", 9, 9, "Force overwrites of existing objects", 13
        =       "-Newer", 9, 9, "Copy only if the source is more recent than the destination", 13
        =       "-Faster", 9, 9, "Perform operation faster", 13

Filer_Options_Syntax
        =       "Syntax: *"
        =       TokenEscapeChar,Token0
        =       " <switches>", 0

Filer_Layout_Help
        =       "*", TokenEscapeChar,Token0
        =       " sets the default layout for filer viewers.", 13

Filer_Layout_Syntax
        =       "Syntax: *"
        =       TokenEscapeChar,Token0
        =       " [-LargeIcons|-SmallIcons|-FullInfo] [-SortByName|-SortByType|-SortBySize|-SortByDate] [-ReverseSort] [-NumericalSort]", 0

Filer_DClickHold_Help
        =       "*", TokenEscapeChar,Token0
        =       " sets time second mouseclick must be held down for.", 13

Filer_DClickHold_Syntax
        =       "Syntax: *"
        =       TokenEscapeChar,Token0
        =       " delay in cs", 0

Desktop_Filer_Help
        =       "The Filer is the Desktop file management tool.",13
        =       "Do not use *",TokenEscapeChar,Token0,","
        =       " use *Desktop instead."
        =       0

; don't fall into syntax msg!

Desktop_Filer_Syntax
        =       "Syntax: *"
        =       TokenEscapeChar,Token0
        =       "", 0
        |
Filer_OpenDir_Help      DCB "HFLROPD",0
Filer_OpenDir_Syntax    DCB "SFLROPD",0

Filer_CloseDir_Help     DCB "HFLRCLD",0
Filer_CloseDir_Syntax   DCB "SFLRCLD",0

Filer_Run_Help          DCB "HFLRRUN",0
Filer_Run_Syntax        DCB "SFLRRUN",0

Filer_Boot_Help         DCB "HFLRBOO",0
Filer_Boot_Syntax       DCB "SFLRBOO",0

Filer_Truncation_Help   DCB "HFLRTRU",0
Filer_Truncation_Syntax DCB "SFLRTRU",0

Filer_Options_Help      DCB "HFLROPT",0
Filer_Options_Syntax    DCB "SFLROPT",0

Filer_Layout_Help       DCB "HFLRLAY",0
Filer_Layout_Syntax     DCB "SFLRLAY",0

Filer_DClickHold_Help   DCB "HFLRDCH",0
Filer_DClickHold_Syntax DCB "SFLRDCH",0

Desktop_Filer_Help      DCB "HFLRDFL",0
Desktop_Filer_Syntax    DCB "SFLRDFL",0
        ]


        END
