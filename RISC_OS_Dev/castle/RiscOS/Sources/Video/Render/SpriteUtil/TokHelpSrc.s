     TTL ==> s.TokHelpSrc

        SUBT    > <wini>arm.SpriteUtil.HelpSrc

 [ International_Help = 0
SChoose_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," selects a ",TokenEscapeChar,Token31
     =  ".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " selects a sprite."
         ;=       13
SChoose_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token11,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <name>",0


SDelete_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," deletes ",TokenEscapeChar,Token31
     =  "s.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " deletes sprites."
         ;=       13
SDelete_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token11,"> [<"
     =  TokenEscapeChar,Token11,">]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <name> [<name>]",0


SList_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," lists",TokenEscapeChar,Token38
     =  TokenEscapeChar,Token31,"s.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " lists all sprites."
         ;=       13
SList_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       "",0


SLoad_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," loads a ",TokenEscapeChar,Token31
     =  " ",TokenEscapeChar,Token7," into memory.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " loads a sprite file into memory."
         ;=       13
SLoad_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token27,  0
         ;=       TokenEscapeChar,Token0
         ;=       " <filename>",0


SMerge_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," appends a ",TokenEscapeChar,Token31
     =  " ",TokenEscapeChar,Token7,TokenEscapeChar,Token40,"those i"
     =  "n memory.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " appends a sprite file to those in memory."
         ;=       13
SMerge_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token27,  0
         ;=       TokenEscapeChar,Token0
         ;=       " <filename>",0


SNew_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," clears",TokenEscapeChar,Token38
     =  TokenEscapeChar,Token31," defini",TokenEscapeChar,Token9,"s"
     =  ".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " clears all sprite definitions."
         ;=       13
SNew_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       "",0


SFlipX_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," reflects",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token31," about",TokenEscapeChar,Token2,"X "
     =  "axis.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " reflects the sprite about the X axis."
         ;=       13
SFlipX_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token11,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <name>",0


SFlipY_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," reflects",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token31," about",TokenEscapeChar,Token2,"Y "
     =  "axis.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " reflects the sprite about the Y axis."
         ;=       13
SFlipY_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token11,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <name>",0


SRename_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," re",TokenEscapeChar,Token11,"s "
     =  "a ",TokenEscapeChar,Token31,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " renames a sprite."
         ;=       13
SRename_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,"old ",TokenEscapeChar,Token11,"> <n"
     =  "ew ",TokenEscapeChar,Token11,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <old name> <new name>",0


SCopy_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," makes a copy of a "
     =  TokenEscapeChar,Token31,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " makes a copy of a sprite."
         ;=       13
SCopy_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token11,"> <new "
     =  TokenEscapeChar,Token11,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <name> <new name>",0


SSave_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," saves",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token31," memory.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " saves the sprite memory."
         ;=       13
SSave_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token27,  0
         ;=       TokenEscapeChar,Token0
         ;=       " <filename>",0


SGet_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," picks up an area of"
     =  TokenEscapeChar,Token2,"screen as a ",TokenEscapeChar,Token31
     =  ".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " picks up an area of the screen as a sprite."
         ;=       13
SGet_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token11,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <name>",0


SInfo_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," prints",TokenEscapeChar,Token2
     =  "size of",TokenEscapeChar,Token2,TokenEscapeChar,Token31," "
     =  "memory.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " prints the size of the sprite memory."
         ;=       13
SInfo_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       "",0


ScreenSave_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," saves",TokenEscapeChar,Token2,"g"
     =  "raphics window.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " saves the graphics window."
         ;=       13
ScreenSave_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token27,  0
         ;=       TokenEscapeChar,Token0
         ;=       " <filename>",0


ScreenLoad_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," loads into",TokenEscapeChar,Token2
     =  "graphics window.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " loads into the graphics window."
         ;=       13
ScreenLoad_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token27,  0
         ;=       TokenEscapeChar,Token0
         ;=       " <filename>",0
 |
SChoose_Help    DCB     "HSPUSCH", 0
SChoose_Syntax  DCB     "SSPUSCH", 0
SDelete_Help    DCB     "HSPUDEL", 0
SDelete_Syntax  DCB     "SSPUDEL", 0
SList_Help      DCB     "HSPULST", 0
SList_Syntax    DCB     "SSPULST", 0
SLoad_Help      DCB     "HSPUSLD", 0
SLoad_Syntax    DCB     "SSPUSLD", 0
SMerge_Help     DCB     "HSPUMRG", 0
SMerge_Syntax   DCB     "SSPUMRG", 0
SNew_Help       DCB     "HSPUNEW", 0
SNew_Syntax     DCB     "SSPUNEW", 0
SFlipX_Help     DCB     "HSPUSFX", 0
SFlipX_Syntax   DCB     "SSPUSFX", 0
SFlipY_Help     DCB     "HSPUSFY", 0
SFlipY_Syntax   DCB     "SSPUSFY", 0
SRename_Help    DCB     "HSPUREN", 0
SRename_Syntax  DCB     "SSPUREN", 0
SCopy_Help      DCB     "HSPUCPY", 0
SCopy_Syntax    DCB     "SSPUCPY", 0
SSave_Help      DCB     "HSPUSSV", 0
SSave_Syntax    DCB     "SSPUSSV", 0
SGet_Help       DCB     "HSPUSGT", 0
SGet_Syntax     DCB     "SSPUSGT", 0
SInfo_Help      DCB     "HSPUINF", 0
SInfo_Syntax    DCB     "SSPUINF", 0
ScreenSave_Help         DCB     "HSPUSCS", 0
ScreenSave_Syntax       DCB     "SSPUSCS", 0
ScreenLoad_Help         DCB     "HSPUSCL", 0
ScreenLoad_Syntax       DCB     "SSPUSCL", 0
 ]

        ALIGN

        END
