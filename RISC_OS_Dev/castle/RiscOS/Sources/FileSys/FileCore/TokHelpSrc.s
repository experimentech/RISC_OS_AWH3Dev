     TTL ==> s.TokHelpSrc

;>HelpText

 [ International_Help=0
Backup_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," copies one whole floppy "
     =  TokenEscapeChar,Token39,", (except ",TokenEscapeChar,Token33
     =  ")",TokenEscapeChar,Token40,"another.", 13
  ;= TokenEscapeChar,Token0
  ;= " copies one whole floppy disc, (except free space) to another.",13
Backup_Syntax
  ;= "Syntax: " 
     =  TokenEscapeChar,Token14,"source drive> <dest. drive> [Q]",  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " <source drive> <dest. drive> [Q]"
  ;= 0

Bye_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," closes",TokenEscapeChar,Token38
     =  TokenEscapeChar,Token7,"s, unsets",TokenEscapeChar,Token38
     =  TokenEscapeChar,Token3,"ies,",TokenEscapeChar,Token16,"park"
     =  "s hard ",TokenEscapeChar,Token39,"s.", 13
  ;= TokenEscapeChar,Token0
  ;= " closes all files, unsets all directories, and parks hard discs.",13
Bye_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token1,  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= 0

CheckMap_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," checks that",TokenEscapeChar,Token2
     =  "map of a new map ",TokenEscapeChar,Token39," has"
     =  TokenEscapeChar,Token2,"correct checksums,"
     =  TokenEscapeChar,Token16,"is consistent with"
     =  TokenEscapeChar,Token2,TokenEscapeChar,Token3,"y tree. If"
     =  " only one copy",TokenEscapeChar,Token41,"good it allows you"
     =  TokenEscapeChar,Token40,"rewrite",TokenEscapeChar,Token2,"o"
     =  "ther.", 13
  ;= TokenEscapeChar,Token0
  ;= " checks that the map of a new map disc has the correct checksums, and is consistent with the directory tree. If only one copy is good it allows you to rewrite the other.",13
CheckMap_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token20,  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " [<disc spec.>]"
  ;= 0

Compact_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," tries",TokenEscapeChar,Token40,"c"
     =  "ollect ",TokenEscapeChar,Token33,"s together by moving "
     =  TokenEscapeChar,Token7,"s.", 13
  ;= TokenEscapeChar,Token0
  ;= " tries to collect free spaces together by moving files.",13
Compact_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token20,  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " [<disc spec.>]"
  ;= 0

Defect_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," maps out a defect from a new map"
     =  " ",TokenEscapeChar,Token39," if it lies in an unallocated par"
     =  "t of",TokenEscapeChar,Token2,TokenEscapeChar,Token39,". Ot"
     =  "herwise it searches for",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token37," containing",TokenEscapeChar,Token2
     =  "defect.", 13
  ;= TokenEscapeChar,Token0
  ;= " maps out a defect from a new map disc if it lies in an unallocated part of the disc. Otherwise it searches for the object containing the defect.",13
Defect_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token39," spec.> <"
     =  TokenEscapeChar,Token39," add.>",  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " <disc spec.> <disc add.>"
  ;= 0

Dismount_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," closes ",TokenEscapeChar,Token7
     =  "s, unsets ",TokenEscapeChar,Token3,"ies",TokenEscapeChar,Token16
     =  "parks",TokenEscapeChar,Token2,"given ",TokenEscapeChar,Token39
     =  ".", 13
  ;= TokenEscapeChar,Token0
  ;= " closes files, unsets directories and parks the given disc.",13
Dismount_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token20,  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " [<disc spec.>]"
  ;= 0

Drive_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," ",TokenEscapeChar,Token19
     =  TokenEscapeChar,Token8,"drive",TokenEscapeChar,Token40,"use"
     =  " if",TokenEscapeChar,Token2,TokenEscapeChar,Token3,"y"
     =  TokenEscapeChar,Token41,"unset.", 13
  ;= TokenEscapeChar,Token0
  ;= " sets the default drive to use if the directory is unset.",13
Drive_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token14,"drive>",  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " <drive>"
  ;= 0

Free_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0,TokenEscapeChar,Token32
     =  TokenEscapeChar,Token2,"total ",TokenEscapeChar,Token33," o"
     =  "n a ",TokenEscapeChar,Token39,".", 13
  ;= TokenEscapeChar,Token0
  ;= " displays the total free space on a disc.",13
Free_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token20,  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " [<disc spec.>]"
  ;= 0

Map_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0,TokenEscapeChar,Token32," a "
     =  TokenEscapeChar,Token39,"'s ",TokenEscapeChar,Token33," map."
     =   13
  ;= TokenEscapeChar,Token0
  ;= " displays a disc's free space map.",13
Map_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token20,  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " [<disc spec.>]"
  ;= 0

Mount_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," ",TokenEscapeChar,Token19
     =  TokenEscapeChar,Token3,"y",TokenEscapeChar,Token40,"the roo"
     =  "t ",TokenEscapeChar,Token3,"y of",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token39,", ",TokenEscapeChar,Token19
     =  TokenEscapeChar,Token35," if unset",TokenEscapeChar,Token40,"$"
     =  ".Library if it exists,",TokenEscapeChar,Token16,"un"
     =  TokenEscapeChar,Token19,"URD.", 13,"The ",TokenEscapeChar,Token8
     =  "is",TokenEscapeChar,Token2,TokenEscapeChar,Token8,"drive."
     =   13
  ;= TokenEscapeChar,Token0
  ;= " sets the directory to the root directory of the disc, sets the library if unset to $.Library if it exists, and unsets the URD.",13
  ;= "The default is the default drive.",13
Mount_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token20,  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " [<disc spec.>]"
  ;= 0

NameDisc_Help
NameDisk_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," alters a ",TokenEscapeChar,Token39
     =  "'s ",TokenEscapeChar,Token11,".", 13
  ;= TokenEscapeChar,Token0
  ;= " alters a disc's name.",13
NameDisc_Syntax
NameDisk_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token14,TokenEscapeChar,Token39," spec.> <"
     =  TokenEscapeChar,Token39," ",TokenEscapeChar,Token11,">",  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " <disc spec.> <disc name>"
  ;= 0

Verify_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," checks",TokenEscapeChar,Token2
     =  "whole ",TokenEscapeChar,Token39,TokenEscapeChar,Token41,"re"
     =  "adable.", 13,"The ",TokenEscapeChar,Token8,"is"
     =  TokenEscapeChar,Token2,TokenEscapeChar,Token5," "
     =  TokenEscapeChar,Token39,".", 13
  ;= TokenEscapeChar,Token0
  ;= " checks the whole disc is readable.",13
  ;= "The default is the current disc.",13
Verify_Syntax
  ;= "Syntax: "
     =  TokenEscapeChar,Token20,  0
  ;= "*"
  ;= TokenEscapeChar,Token0
  ;= " [<disc spec.>]"
  ;= 0
 |
Backup_Help     DCB     "HFLCBKU", 0
Backup_Syntax   DCB     "SFLCBKU", 0

Bye_Help        DCB     "HFLCBYE", 0
Bye_Syntax      DCB     "SFLCBYE", 0

CheckMap_Help   DCB     "HFLCCKM", 0
CheckMap_Syntax DCB     "SFLCCKM", 0

Compact_Help    DCB     "HFLCCOM", 0
Compact_Syntax  DCB     "SFLCCOM", 0

Defect_Help     DCB     "HFLCDEF", 0
Defect_Syntax   DCB     "SFLCDEF", 0

Dismount_Help   DCB     "HFLCDIS", 0
Dismount_Syntax DCB     "SFLCDIS", 0

Drive_Help      DCB     "HFLCDRV", 0
Drive_Syntax    DCB     "SFLCDRV", 0

Free_Help       DCB     "HFLCFRE", 0
Free_Syntax     DCB     "SFLCFRE", 0

Map_Help        DCB     "HFLCMAP", 0
Map_Syntax      DCB     "SFLCMAP", 0

Mount_Help      DCB     "HFLCMNT", 0
Mount_Syntax    DCB     "SFLCMNT", 0

NameDisc_Help
NameDisk_Help   DCB     "HFLCNDS", 0
NameDisc_Syntax
NameDisk_Syntax DCB     "SFLCNDS", 0

Verify_Help     DCB     "HFLCVER", 0
Verify_Syntax   DCB     "SFLCVER", 0
 ]

        ALIGN
        
        END
