     TTL ==> s.TokHelpSrc

        SUBT    > Sources.HelpSrc

 [ International_Help <> 0

Access_Help      ;=       "HFLSACC",0
     =  "HFLSACC",  0
Access_Syntax    ;=       "SFLSACC",0
     =  "SFLSACC",  0

Cat_Help         ;=       "HFLSCAT",0
     =  "HFLSCAT",  0
Cat_Syntax       ;=       "SFLSCAT",0
     =  "SFLSCAT",  0

CDir_Help        ;=       "HFLSCDR",0
     =  "HFLSCDR",  0
CDir_Syntax      ;=       "SFLSCDR",0
     =  "SFLSCDR",  0

 [ hascopy
Copy_Help        ;=       "HFLSCPY",0
     =  "HFLSCPY",  0
Copy_Syntax      ;=       "SFLSCPY",0
     =  "SFLSCPY",  0
 ]

 [ hascount
Count_Help       ;=       "HFLSCNT",0
     =  "HFLSCNT",  0
Count_Syntax     ;=       "SFLSCNT",0
     =  "SFLSCNT",  0
 ]

Dir_Help         ;=       "HFLSDIR",0
     =  "HFLSDIR",  0
Dir_Syntax       ;=       "SFLSDIR",0
     =  "SFLSDIR",  0

EnumDir_Help     ;=       "HFLSEDR",0
     =  "HFLSEDR",  0
EnumDir_Syntax   ;=       "SFLSEDR",0
     =  "SFLSEDR",  0

Ex_Help          ;=       "HFLSEX",0
     =  "HFLSEX",  0
Ex_Syntax        ;=       "SFLSEX",0
     =  "SFLSEX",  0

FileInfo_Help    ;=       "HFLSFIN",0
     =  "HFLSFIN",  0
FileInfo_Syntax  ;=       "SFLSFIN",0
     =  "SFLSFIN",  0

Info_Help        ;=       "HFLSINF",0
     =  "HFLSINF",  0
Info_Syntax      ;=       "SFLSINF",0
     =  "SFLSINF",  0

LCat_Help        ;=       "HFLSLCT",0
     =  "HFLSLCT",  0
LCat_Syntax      ;=       "SFLSLCT",0
     =  "SFLSLCT",  0

LEx_Help         ;=       "HFLSLEX",0
     =  "HFLSLEX",  0
LEx_Syntax       ;=       "SFLSLEX",0
     =  "SFLSLEX",  0

Lib_Help         ;=       "HFLSLIB",0
     =  "HFLSLIB",  0
Lib_Syntax       ;=       "SFLSLIB",0
     =  "SFLSLIB",  0

Rename_Help      ;=       "HFLSREN",0
     =  "HFLSREN",  0
Rename_Syntax    ;=       "SFLSREN",0
     =  "SFLSREN",  0

Run_Help         ;=       "HFLSRUN",0
     =  "HFLSRUN",  0
Run_Syntax       ;=       "SFLSRUN",0
     =  "SFLSRUN",  0

SetType_Help     ;=       "HFLSSTY",0
     =  "HFLSSTY",  0
SetType_Syntax   ;=       "SFLSSTY",0
     =  "SFLSSTY",  0

Shut_Help        ;=       "HFLSSHT",0
     =  "HFLSSHT",  0
Shut_Syntax      ;=       "SFLSSHT",0
     =  "SFLSSHT",  0

ShutDown_Help    ;=       "HFLSSHD",0
     =  "HFLSSHD",  0
ShutDown_Syntax  ;=       "SFLSSHD",0
     =  "SFLSSHD",  0

Stamp_Help       ;=       "HFLSSTM",0
     =  "HFLSSTM",  0
Stamp_Syntax     ;=       "SFLSSTM",0
     =  "SFLSSTM",  0

Up_Help          ;=       "HFLSUP",0
     =  "HFLSUP",  0
Up_Syntax        ;=       "SFLSUP",0
     =  "SFLSUP",  0

 [ haswipe
Wipe_Help        ;=       "HFLSWIP",0
     =  "HFLSWIP",  0
Wipe_Syntax      ;=       "SFLSWIP",0
     =  "SFLSWIP",  0
 ]

Back_Help        ;=       "HFLSBCK",0
     =  "HFLSBCK",  0
Back_Syntax      ;=       "SFLSBCK",0
     =  "SFLSBCK",  0

URD_Help         ;=       "HFLSURD",0
     =  "HFLSURD",  0
URD_Syntax       ;=       "SFLSURD",0
     =  "SFLSURD",  0

NoDir_Help       ;=       "HFLSNDR",0
     =  "HFLSNDR",  0
NoDir_Syntax     ;=       "SFLSNDR",0
     =  "SFLSNDR",  0

NoURD_Help       ;=       "HFLSNUR",0
     =  "HFLSNUR",  0
NoURD_Syntax     ;=       "SFLSNUR",0
     =  "SFLSNUR",  0

NoLib_Help       ;=       "HFLSNLB",0
     =  "HFLSNLB",  0
NoLib_Syntax     ;=       "SFLSNLB",0
     =  "SFLSNLB",  0

FileSystem_Help  ;=       "HFLSCFS",0
     =  "HFLSCFS",  0
FileSystem_Syntax  ;=     "SFLSCFS",0
     =  "SFLSCFS",  0

Truncate_Help    ;=       "HFLSCTR",0
     =  "HFLSCTR",  0
Truncate_Syntax  ;=       "SFLSCTR",0
     =  "SFLSCTR",  0

 |

Access_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," changes",TokenEscapeChar,Token2
     =  "attributes of",TokenEscapeChar,Token38,TokenEscapeChar,Token37
     =  "s matching",TokenEscapeChar,Token2,"wildcarded specifica"
     =  TokenEscapeChar,Token9,".", 13,"Attributes:", 13,"L(ock)",  9
     =    9,"Lock ",TokenEscapeChar,Token37," against dele"
     =  TokenEscapeChar,Token9, 13,"R(ead)",  9,  9,"Read permissi"
     =  "on", 13,"W(rite)",  9,  9,"Write permission", 13,"/R,/W,/RW",  9
     =  "Public read",TokenEscapeChar,Token16,"write permission", 13
         ;=       TokenEscapeChar,Token0
         ;=       " changes the attributes of all objects matching the"
         ;=       " wildcarded specification."
         ;=       13,"Attributes:"
         ;=       13,"L(ock)",9,9
         ;=          "Lock object against deletion"
         ;=       13,"R(ead)",9,9
         ;=          "Read permission"
         ;=       13,"W(rite)",9,9
         ;=          "Write permission"
         ;=       13,"/R,/W,/RW",9
         ;=          "Public read and write permission"
         ;=       13
Access_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token37,"> [<attrib"
     =  "utes>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <object> [<attributes>]",0

Cat_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," lists all",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token37,"s in a ",TokenEscapeChar,Token3,"y"
     =  " (",TokenEscapeChar,Token8,"is ",TokenEscapeChar,Token5," "
     =  TokenEscapeChar,Token3,"y).", 13
         ;=       TokenEscapeChar,Token0
         ;=       " lists all the objects in a directory"
         ;=       " (default is current directory)."
         ;=       13
Cat_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"<",TokenEscapeChar,Token3,"y>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [<directory>]",0

CDir_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," creates a ",TokenEscapeChar,Token3
     =  "y of given ",TokenEscapeChar,Token11," (and size on Net only)"
     =  ".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " creates a directory of given name"
         ;=       " (and size on Net only)."
         ;=       13
CDir_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token3,"y> [<size "
     =  "in entries>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <directory> [<size in entries>]",0

 [ hascopy
Copy_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," copies one or more "
     =  TokenEscapeChar,Token37,"s that match",TokenEscapeChar,Token2
     =  "given wildcarded specifica",TokenEscapeChar,Token9," between"
     =  " ",TokenEscapeChar,Token3,"ies. Op",TokenEscapeChar,Token9
     =  "s are taken from",TokenEscapeChar,Token2,"system variable Co"
     =  "py$Op",TokenEscapeChar,Token9,"s ",TokenEscapeChar,Token16,"t"
     =  "hose given",TokenEscapeChar,Token40,"the command.", 13,"Op"
     =  TokenEscapeChar,Token9,"s: (use ~",TokenEscapeChar,Token40,"f"
     =  "orce off,eg. ~C)", 13,"A(ccess)",  9,"Force destina"
     =  TokenEscapeChar,Token9," access",TokenEscapeChar,Token40,"s"
     =  "ame as source {on}",TokenEscapeChar,Token18,"copy {on}", 13,"D"
     =  "(elete)",  9,"Delete",TokenEscapeChar,Token2,"source "
     =  TokenEscapeChar,Token37," after copy",TokenEscapeChar,Token34
     =   13,"F(orce)",  9,  9,"Force overwriting of existing "
     =  TokenEscapeChar,Token37,"s",TokenEscapeChar,Token34, 13,"L("
     =  "ook)",  9,  9,"Look at destina",TokenEscapeChar,Token9," be"
     =  "fore loading source ",TokenEscapeChar,Token7
     =  TokenEscapeChar,Token34, 13,"N(ewer)",  9,  9,"Copy only if"
     =  " source",TokenEscapeChar,Token41,"more recent than destina"
     =  TokenEscapeChar,Token9,TokenEscapeChar,Token34, 13,"P(rom"
     =  "pt)",  9,"Prompt for",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token39,TokenEscapeChar,Token40,"be changed"
     =  " as needed in copy",TokenEscapeChar,Token34, 13,"Q(uick)",  9
     =    9,"Use applica",TokenEscapeChar,Token9," workspace"
     =  TokenEscapeChar,Token40,"speed ",TokenEscapeChar,Token7," t"
     =  "ransfer",TokenEscapeChar,Token34, 13,"R(ecurse)",  9,"Copy s"
     =  "ub",TokenEscapeChar,Token3,"ies",TokenEscapeChar,Token16,"c"
     =  "ontents",TokenEscapeChar,Token34, 13,"S(tamp)",  9,  9,"Res"
     =  "tamp datestamped ",TokenEscapeChar,Token7,"s after copying"
     =  TokenEscapeChar,Token34, 13,"sT(ructure)",  9,"Copy only"
     =  TokenEscapeChar,Token2,TokenEscapeChar,Token3,"y structur"
     =  "e",TokenEscapeChar,Token34, 13,"V(erbose)",  9,"Print inform"
     =  "a",TokenEscapeChar,Token9," on each ",TokenEscapeChar,Token37
     =  " copied {on}", 13
         ;=       TokenEscapeChar,Token0
         ;=       " copies one or more objects that match the given"
         ;=       " wildcarded specification between directories."
         ;=       " Options are taken from the system variable Copy$Options "
         ;=       " and those given to the command."
         ;=       13,"Options: (use ~ to force off,eg. ~C)"
         ;=       13,"A(ccess)",9
         ;=          "Force destination access to same as source {on}"
         ;=       13,"C(onfirm)",9
         ;=          "Prompt for confirmation of each copy {on}"
         ;=       13,"D(elete)",9
         ;=          "Delete the source object after copy {off}"
         ;=       13,"F(orce)",9,9
         ;=          "Force overwriting of existing objects {off}"
         ;=       13,"L(ook)",9,9
         ;=          "Look at destination before loading source file {off}"
         ;=       13,"N(ewer)",9,9
         ;=          "Copy only if source is more recent than destination {off}"
         ;=       13,"P(rompt)",9
         ;=          "Prompt for the disc to be changed as needed in copy {off}"
         ;=       13,"Q(uick)",9,9
         ;=          "Use application workspace to speed file transfer {off}"
         ;=       13,"R(ecurse)",9
         ;=          "Copy subdirectories and contents {off}"
         ;=       13,"S(tamp)",9,9
         ;=          "Restamp datestamped files after copying {off}"
         ;=       13,"sT(ructure)",9
         ;=          "Copy only the directory structure {off}"
         ;=       13,"V(erbose)",9
         ;=          "Print information on each object copied {on}"
         ;=       13
Copy_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,"source spec> <destina"
     =  TokenEscapeChar,Token9," spec> [<op",TokenEscapeChar,Token9
     =  "s>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <source spec> <destination spec> [<options>]",0
 ]

 [ hascount
Count_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," adds up",TokenEscapeChar,Token2
     =  "size of",TokenEscapeChar,Token15,"ed specifica"
     =  TokenEscapeChar,Token9,". Op",TokenEscapeChar,Token9,"s ar"
     =  "e taken from",TokenEscapeChar,Token2,"system variable Count$"
     =  "Op",TokenEscapeChar,Token9,"s ",TokenEscapeChar,Token16,"th"
     =  "ose given",TokenEscapeChar,Token40,"the command.", 13,"Op"
     =  TokenEscapeChar,Token9,"s: (use ~",TokenEscapeChar,Token40,"f"
     =  "orce off,eg. ~R)",TokenEscapeChar,Token18,"count"
     =  TokenEscapeChar,Token34, 13,"R(ecurse)",  9,"Count sub"
     =  TokenEscapeChar,Token3,"ies",TokenEscapeChar,Token16,"conte"
     =  "nts {on",TokenEscapeChar,Token21,"counted"
     =  TokenEscapeChar,Token34, 13
         ;=       TokenEscapeChar,Token0
         ;=       " adds up the size of one or more files that"
         ;=       " match the given wildcarded specification."
         ;=       " Options are taken from the system variable Count$Options "
         ;=       " and those given to the command."
         ;=       13,"Options: (use ~ to force off,eg. ~R)"
         ;=       13,"C(onfirm)",9
         ;=          "Prompt for confirmation of each count {off}"
         ;=       13,"R(ecurse)",9
         ;=          "Count subdirectories and contents {on}"
         ;=       13,"V(erbose)",9
         ;=          "Print information on each file counted {off}"
         ;=       13
Count_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token7," spec> [<o"
     =  "p",TokenEscapeChar,Token9,"s>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <file spec> [<options>]",0
 ]

Dir_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," selects a ",TokenEscapeChar,Token3
     =  "y as",TokenEscapeChar,Token2,TokenEscapeChar,Token5," "
     =  TokenEscapeChar,Token3,"y (",TokenEscapeChar,Token8,"is us"
     =  "er root ",TokenEscapeChar,Token3,"y).", 13
         ;=       TokenEscapeChar,Token0
         ;=       " selects a directory as the current directory"
         ;=       " (default is user root directory)."
         ;=       13
Dir_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"<",TokenEscapeChar,Token3,"y>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [<directory>]",0

EnumDir_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," creates a ",TokenEscapeChar,Token7
     =  " of ",TokenEscapeChar,Token7,TokenEscapeChar,Token11,"s fr"
     =  "om a ",TokenEscapeChar,Token3,"y that match"
     =  TokenEscapeChar,Token2,"supplied wildcarded specifica"
     =  TokenEscapeChar,Token9," (",TokenEscapeChar,Token8,"is *)."
     =   13
         ;=       TokenEscapeChar,Token0
         ;=       " creates a file of filenames from a directory that"
         ;=       " match the supplied wildcarded specification (default is *)."
         ;=       13
EnumDir_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token3,"y> <output"
     =  " ",TokenEscapeChar,Token7,"> [<pattern>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <directory> <output file> [<pattern>]",0

Ex_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," lists all",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token37,"s in a ",TokenEscapeChar,Token3,"y"
     =  " together with their ",TokenEscapeChar,Token7," informa"
     =  TokenEscapeChar,Token9," (",TokenEscapeChar,Token8,"is "
     =  TokenEscapeChar,Token5," ",TokenEscapeChar,Token3,"y).", 13
         ;=       TokenEscapeChar,Token0
         ;=       " lists all the objects in a directory together"
         ;=       " with their file information (default is current directory)."
         ;=       13
Ex_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"<",TokenEscapeChar,Token3,"y>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [<directory>]",0

FileInfo_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," yields",TokenEscapeChar,Token2
     =  "full ",TokenEscapeChar,Token7," informa",TokenEscapeChar,Token9
     =  " of an ",TokenEscapeChar,Token37,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " yields the full file information of an object."
         ;=       13
FileInfo_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token37,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <object>",0

Info_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," lists",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token7," informa",TokenEscapeChar,Token9," "
     =  "of",TokenEscapeChar,Token38,TokenEscapeChar,Token37,"s matc"
     =  "hing",TokenEscapeChar,Token2,"given wildcarded specifica"
     =  TokenEscapeChar,Token9,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " lists the file information of all objects matching"
         ;=       " the given wildcarded specification."
         ;=       13
Info_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token37,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <object>",0

LCat_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," lists all",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token37,"s in a sub",TokenEscapeChar,Token3
     =  "y relative",TokenEscapeChar,Token40,TokenEscapeChar,Token2
     =  TokenEscapeChar,Token35," (",TokenEscapeChar,Token8,"is "
     =  TokenEscapeChar,Token5," ",TokenEscapeChar,Token35,").", 13
         ;=       TokenEscapeChar,Token0
         ;=       " lists all the objects in a subdirectory relative to "
         ;=       " the library (default is current library)."
         ;=       13
LCat_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"<",TokenEscapeChar,Token3,"y>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [<directory>]",0

LEx_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," lists all",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token37,"s in a sub",TokenEscapeChar,Token3
     =  "y of",TokenEscapeChar,Token2,TokenEscapeChar,Token35," tog"
     =  "ether with their ",TokenEscapeChar,Token7," informa"
     =  TokenEscapeChar,Token9," (",TokenEscapeChar,Token8,"is "
     =  TokenEscapeChar,Token5," ",TokenEscapeChar,Token35,").", 13
         ;=       TokenEscapeChar,Token0
         ;=       " lists all the objects in a subdirectory of"
         ;=       " the library together with their file information"
         ;=       " (default is current library)."
         ;=       13
LEx_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"<",TokenEscapeChar,Token3,"y>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [<directory>]",0

Lib_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," selects a ",TokenEscapeChar,Token3
     =  "y as",TokenEscapeChar,Token2,TokenEscapeChar,Token5," "
     =  TokenEscapeChar,Token35," (",TokenEscapeChar,Token8,"is "
     =  TokenEscapeChar,Token4," dependent).", 13
         ;=       TokenEscapeChar,Token0
         ;=       " selects a directory as the current library"
         ;=       " (default is filing system dependent)."
         ;=       13
Lib_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"<",TokenEscapeChar,Token3,"y>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [<directory>]",0

Rename_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," changes",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token11," of an ",TokenEscapeChar,Token37,"."
     =  " It cannot be used",TokenEscapeChar,Token40,"move "
     =  TokenEscapeChar,Token37,"s between ",TokenEscapeChar,Token4
     =  "s or between ",TokenEscapeChar,Token39,"s on"
     =  TokenEscapeChar,Token2,"same ",TokenEscapeChar,Token4,"; *"
     =  "Copy with",TokenEscapeChar,Token2,"D(elete) op"
     =  TokenEscapeChar,Token9," must be used instead.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " changes the name of an object."
         ;=       " It cannot be used to move objects between filing systems or"
         ;=       " between discs on the same filing system;"
         ;=       " *Copy with the D(elete) option must be used instead."
         ;=       13
Rename_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token37,"> <new "
     =  TokenEscapeChar,Token11,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <object> <new name>",0

Run_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," loads",TokenEscapeChar,Token16,"e"
     =  "xecutes",TokenEscapeChar,Token2,TokenEscapeChar,Token11,"d"
     =  " ",TokenEscapeChar,Token7,", passing op",TokenEscapeChar,Token9
     =  "al ",TokenEscapeChar,Token36,"s",TokenEscapeChar,Token40,"it"
     =  ".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " loads and executes the named file,"
         ;=       " passing optional parameters to it."
         ;=       13
Run_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token27," [<",TokenEscapeChar,Token36,"s>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <filename> [<parameters>]",0

SetType_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," ",TokenEscapeChar,Token19
     =  TokenEscapeChar,Token7," type of",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token11,"d ",TokenEscapeChar,Token7
     =  TokenEscapeChar,Token40,"the given textual "
     =  TokenEscapeChar,Token7," type or hexadecimal "
     =  TokenEscapeChar,Token13,". If",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token7,TokenEscapeChar,Token41,"not alread"
     =  "y datestamped then it",TokenEscapeChar,Token41,"also stamped "
     =  "with",TokenEscapeChar,Token2,TokenEscapeChar,Token5," tim"
     =  "e",TokenEscapeChar,Token16,"date.", 13,"""*Show File$Type*"""
     =  TokenEscapeChar,Token32," ",TokenEscapeChar,Token5,"ly know"
     =  "n ",TokenEscapeChar,Token7," types.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " sets the file type of the named file to the given"
         ;=       " textual file type or hexadecimal number. If the file is"
         ;=       " not already datestamped then it is also stamped with the"
         ;=       " current time and date."
         ;=       13
         ;=       """*Show File$Type*"" displays currently known file types."
         ;=       13
SetType_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token27," <",TokenEscapeChar,Token7," type>"
     =    0
         ;=       TokenEscapeChar,Token0
         ;=       " <filename> <file type>",0

Shut_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," closes",TokenEscapeChar,Token38
     =  "open ",TokenEscapeChar,Token7,"s on",TokenEscapeChar,Token38
     =  TokenEscapeChar,Token4,"s.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " closes all open files on all filing systems."
         ;=       13
Shut_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       "",0

ShutDown_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," closes",TokenEscapeChar,Token38
     =  "open ",TokenEscapeChar,Token7,"s on",TokenEscapeChar,Token38
     =  TokenEscapeChar,Token4,"s, logs off ",TokenEscapeChar,Token7
     =  TokenEscapeChar,Token12,"s",TokenEscapeChar,Token16,"causes "
     =  "hard ",TokenEscapeChar,Token39,"s",TokenEscapeChar,Token40,"b"
     =  "e parked.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " closes all open files on all filing systems,"
         ;=       " logs off file servers and causes hard discs to be parked."
         ;=       13
ShutDown_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       "",0

Stamp_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," ",TokenEscapeChar,Token19,"date"
     =  "stamp on a ",TokenEscapeChar,Token7,TokenEscapeChar,Token40
     =  "the ",TokenEscapeChar,Token5," time",TokenEscapeChar,Token16
     =  "date. If",TokenEscapeChar,Token2,TokenEscapeChar,Token7
     =  TokenEscapeChar,Token41,"not already datestamped then it"
     =  TokenEscapeChar,Token41,"given ",TokenEscapeChar,Token7," t"
     =  "ype Data (&FFD).", 13
         ;=       TokenEscapeChar,Token0
         ;=       " sets the datestamp on a file to the current time and date."
         ;=       " If the file is not already datestamped then it is given"
         ;=       " file type Data (&FFD)."
         ;=       13
Stamp_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token27,  0
         ;=       TokenEscapeChar,Token0
         ;=       " <filename>",0

Up_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," moves",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token5," ",TokenEscapeChar,Token3,"y up"
     =  TokenEscapeChar,Token2,TokenEscapeChar,Token3,"y structur"
     =  "e by",TokenEscapeChar,Token2,"specified "
     =  TokenEscapeChar,Token13," of levels.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " moves the current directory up the directory"
         ;=       " structure by the specified number of levels."
         ;=       13
Up_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"<levels>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [<levels>]",0

 [ haswipe
Wipe_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," deletes one or more "
     =  TokenEscapeChar,Token37,"s that match",TokenEscapeChar,Token2
     =  "given wildcard specifica",TokenEscapeChar,Token9,". Op"
     =  TokenEscapeChar,Token9,"s are taken from"
     =  TokenEscapeChar,Token2,"system variable Wipe$Op"
     =  TokenEscapeChar,Token9,"s ",TokenEscapeChar,Token16,"those "
     =  "given",TokenEscapeChar,Token40,"the command.", 13,"Op"
     =  TokenEscapeChar,Token9,"s: (use ~",TokenEscapeChar,Token40,"f"
     =  "orce off,eg. ~V)",TokenEscapeChar,Token18,"dele"
     =  TokenEscapeChar,Token9," {on}", 13,"F(orce)",  9,  9,"Force"
     =  " dele",TokenEscapeChar,Token9," of locked "
     =  TokenEscapeChar,Token37,"s",TokenEscapeChar,Token34, 13,"R("
     =  "ecurse)",  9,"Delete sub",TokenEscapeChar,Token3,"ies"
     =  TokenEscapeChar,Token16,"contents",TokenEscapeChar,Token34, 13
     =  "V(erbose)",  9,"Print informa",TokenEscapeChar,Token9," on e"
     =  "ach ",TokenEscapeChar,Token37," deleted {on}", 13,"See also *"
     =  "Delete.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " deletes one or more objects that match"
         ;=       " the given wildcard specification."
         ;=       " Options are taken from the system variable Wipe$Options "
         ;=       " and those given to the command."
         ;=       13,"Options: (use ~ to force off,eg. ~V)"
         ;=       13,"C(onfirm)",9
         ;=          "Prompt for confirmation of each deletion {on}"
         ;=       13,"F(orce)",9,9
         ;=          "Force deletion of locked objects {off}"
         ;=       13,"R(ecurse)",9
         ;=          "Delete subdirectories and contents {off}"
         ;=       13,"V(erbose)",9
         ;=          "Print information on each object deleted {on}"
         ;=       13
         ;=       "See also *Delete."
         ;=       13
Wipe_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token7," spec> [<o"
     =  "p",TokenEscapeChar,Token9,"s>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <file spec> [<options>]",0
 ]
Back_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," swaps",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token5,TokenEscapeChar,Token16,"previous "
     =  TokenEscapeChar,Token3,"ies.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " swaps the current and previous directories."
         ;=       13
Back_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       0
URD_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," selects a ",TokenEscapeChar,Token3
     =  "y as",TokenEscapeChar,Token2,"user root "
     =  TokenEscapeChar,Token3,"y (",TokenEscapeChar,Token8,"resto"
     =  "res",TokenEscapeChar,Token2,"URD",TokenEscapeChar,Token40,"&"
     =  " or $ as appropriate).", 13
         ;=       TokenEscapeChar,Token0
         ;=       " selects a directory as the user root directory"
         ;=       " (default restores the URD to & or $ as appropriate)."
         ;=       13
URD_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"<",TokenEscapeChar,Token3,"y>]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [<directory>]",0

NoDir_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," un",TokenEscapeChar,Token19
     =  TokenEscapeChar,Token5,"ly selected ",TokenEscapeChar,Token3
     =  "y on",TokenEscapeChar,Token2,"temporary "
     =  TokenEscapeChar,Token4,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " unsets the currently selected directory on the temporary filing system."
         ;=       13
NoDir_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       0

NoURD_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," un",TokenEscapeChar,Token19,"us"
     =  "er root ",TokenEscapeChar,Token3,"y on",TokenEscapeChar,Token2
     =  "temporary ",TokenEscapeChar,Token4,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " unsets the user root directory on the temporary filing system."
         ;=       13
NoURD_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       0

NoLib_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," un",TokenEscapeChar,Token19
     =  TokenEscapeChar,Token35," ",TokenEscapeChar,Token3,"y on"
     =  TokenEscapeChar,Token2,"temporary ",TokenEscapeChar,Token4
     =  ".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " unsets the library directory on the temporary filing system."
         ;=       13

NoLib_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       0

FileSystem_Help
         ;=       "*Configure "
     =  TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  TokenEscapeChar,Token19,TokenEscapeChar,Token8
     =  TokenEscapeChar,Token4,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " sets the default filing system."
         ;=       13

FileSystem_Syntax
         ;=       "Syntax: *Configure "
     =  "Syntax: ",TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  "<fs ",TokenEscapeChar,Token11,">|<fs ",TokenEscapeChar,Token13
     =  ">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " <fs name>|<fs number>",0

Truncate_Help
         ;=       "*Configure "
     =  TokenEscapeChar,Token10,TokenEscapeChar,Token0," sets whet"
     =  "her ",TokenEscapeChar,Token7,TokenEscapeChar,Token11,"s sh"
     =  "ould be truncated when too long.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " sets whether filenames should be truncated when too long."
         ;=       13
Truncate_Syntax
         ;=       "Syntax: *Configure "
     =  "Syntax: ",TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  "On|Off",  0
         ;=       TokenEscapeChar,Token0
         ;=       " On|Off",0

 ]

        ALIGN

        END
