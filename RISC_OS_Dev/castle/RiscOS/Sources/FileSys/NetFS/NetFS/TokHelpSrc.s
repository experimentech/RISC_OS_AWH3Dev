     TTL ==> s.TokHelpSrc

 SUBT Strings for Help messages. => &.Arthur.NetFS.HelpTexts

        [ international_help

Net_Help
        DCB     "HNFSNET", 0
Net_Syntax
        DCB     "SNFSNET", 0

AddFS_Help
        DCB     "HNFSAFS", 0
AddFS_Syntax
        DCB     "SNFSAFS", 0

Free_Help
        DCB     "HNFSFRE", 0
Free_Syntax
        DCB     "SNFSFRE", 0

FS_Help
        DCB     "HNFSFS", 0
FS_Syntax
        DCB     "SNFSFS", 0

Mount_Help
        DCB     "HNFSMNT", 0
Mount_Syntax
        DCB     "SNFSMNT", 0

SDisc_Help
        DCB     "HNFSSDS", 0
SDisc_Syntax
        DCB     "SNFSSDS", 0

ListFS_Help
        DCB     "HNFSLFS", 0
ListFS_Syntax
        DCB     "SNFSLFS", 0

Bye_Help
        DCB     "HNFSBYE", 0
Bye_Syntax
        DCB     "SNFSBYE", 0

Logon_Help
        DCB     "HNFSLON", 0
Logon_Syntax
        DCB     "SNFSLON", 0

Pass_Help
        DCB     "HNFSPAS", 0
Pass_Syntax
        DCB     "SNFSPAS", 0

ConfigureFS_Help
        DCB     "HNFSCFS", 0
ConfigureFS_Syntax
        DCB     "SNFSCFS", 0

ConfigureLib_Help
        DCB     "HNFSCLB", 0
ConfigureLib_Syntax
        DCB     "SNFSCLB", 0
        | ; international_help

Net_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," selects",TokenEscapeChar,Token2
     =  "network as",TokenEscapeChar,Token2,TokenEscapeChar,Token5
     =  " ",TokenEscapeChar,Token4,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " selects the network as the current filing system.", 13
Net_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       0

AddFS_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," adds",TokenEscapeChar,Token2,"g"
     =  "iven ",TokenEscapeChar,Token7,TokenEscapeChar,Token12
     =  TokenEscapeChar,Token16,TokenEscapeChar,Token39," "
     =  TokenEscapeChar,Token11,TokenEscapeChar,Token40,"those NetF"
     =  "S ",TokenEscapeChar,Token5,"ly knows about.  If only"
     =  TokenEscapeChar,Token2,"sta",TokenEscapeChar,Token9," "
     =  TokenEscapeChar,Token13,TokenEscapeChar,Token41,"given then"
     =  " that sta",TokenEscapeChar,Token9," will be removed from"
     =  TokenEscapeChar,Token2,"list of known ",TokenEscapeChar,Token7
     =  TokenEscapeChar,Token12,"s.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " adds the given file server and disc name to those"
         ;=       " NetFS currently knows about.  If only the station"
         ;=       " number is given then that station will be removed"
         ;=       " from the list of known file servers.", 13
AddFS_Syntax
        DCB     "Syntax: *AddFS"
        DCB     " <station number> [<disc number> [:]<disc name>]", 0

Free_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0,TokenEscapeChar,Token32," your "
     =  TokenEscapeChar,Token5," remaining ",TokenEscapeChar,Token33
     =  " as well as",TokenEscapeChar,Token2,"total "
     =  TokenEscapeChar,Token33," for",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token39,"(s).  If an argument"
     =  TokenEscapeChar,Token41,"given",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token33," for that user ",TokenEscapeChar,Token11
     =  " will be ",TokenEscapeChar,Token26,"d out.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " displays your current remaining"
         ;=       " free space as well as the"
         ;=       " total free space for the disc(s)."
         ;=       "  If an argument is given the free"
         ;=       " space for that user name will be printed out.", 13
Free_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,":<",TokenEscapeChar,Token7
     =  TokenEscapeChar,Token12,">] [<user ",TokenEscapeChar,Token11
     =  ">]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [:<file server>] [<user name>]", 0

FS_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," changes your "
     =  TokenEscapeChar,Token5,"ly selected ",TokenEscapeChar,Token7
     =  TokenEscapeChar,Token12,", restoring any previous context.  I"
     =  "f no argument",TokenEscapeChar,Token41,"supplied"
     =  TokenEscapeChar,Token2,TokenEscapeChar,Token5," "
     =  TokenEscapeChar,Token7,TokenEscapeChar,Token12," "
     =  TokenEscapeChar,Token11," and/or ",TokenEscapeChar,Token13," "
     =  "are ",TokenEscapeChar,Token26,"d out, this"
     =  TokenEscapeChar,Token41,"followed by",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token11,"s",TokenEscapeChar,Token16
     =  TokenEscapeChar,Token13,"s of any other logged on "
     =  TokenEscapeChar,Token7,TokenEscapeChar,Token12,"s.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " changes your currently selected file server, restoring any"
         ;=       " previous context.  If no argument is supplied the current"
         ;=       " file server name and/or number are printed out, this is"
         ;=       " followed by the names and numbers of any other logged on"
         ;=       " file servers.", 13
FS_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"[:]<",TokenEscapeChar,Token7
     =  TokenEscapeChar,Token12,">]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [[:]<file server>]", 0

Mount_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," reselects your user root as well"
     =  " as your ",TokenEscapeChar,Token5,"ly selected "
     =  TokenEscapeChar,Token3,"y",TokenEscapeChar,Token16
     =  TokenEscapeChar,Token35,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " reselects your user root as well as your"
         ;=       " currently selected directory and library.", 13
Mount_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,":]<",TokenEscapeChar,Token39," "
     =  TokenEscapeChar,Token11,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [:]<disc name>", 0

SDisc_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0,TokenEscapeChar,Token41,"synonym"
     =  "ous with *Mount.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " is synonymous with *Mount.", 13
SDisc_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,":]<",TokenEscapeChar,Token39," "
     =  TokenEscapeChar,Token11,">",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [:]<disc name>", 0

ListFS_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," shows those "
     =  TokenEscapeChar,Token7,TokenEscapeChar,Token12,"s that"
     =  TokenEscapeChar,Token2,"NetFS ",TokenEscapeChar,Token5,"ly"
     =  " knows about.  If",TokenEscapeChar,Token2,"op"
     =  TokenEscapeChar,Token9,"al argument",TokenEscapeChar,Token41
     =  "supplied then",TokenEscapeChar,Token2,"list will be refreshe"
     =  "d before it",TokenEscapeChar,Token41,"displayed.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " shows those file servers that the NetFS currently knows"
         ;=       " about.  If the optional argument is supplied then"
         ;=       " the list will be refreshed before it is displayed.", 13
ListFS_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"-force]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [-force]", 0

Bye_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," terminates your use of"
     =  TokenEscapeChar,Token2,TokenEscapeChar,Token5," (or given"
     =  ") ",TokenEscapeChar,Token7,TokenEscapeChar,Token12,". Clos"
     =  "ing",TokenEscapeChar,Token38,"open ",TokenEscapeChar,Token7
     =  "s",TokenEscapeChar,Token16,TokenEscapeChar,Token3,"ies.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " terminates your use of the current (or given)"
         ;=       " file server. Closing all open files and directories.", 13
Bye_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"[:]<",TokenEscapeChar,Token7
     =  TokenEscapeChar,Token12,">]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [[:]<file server>]", 0

Logon_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," initialises",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token5," (or given) ",TokenEscapeChar,Token7
     =  TokenEscapeChar,Token12," for your use. Your user "
     =  TokenEscapeChar,Token11,TokenEscapeChar,Token16,"password a"
     =  "re checked by",TokenEscapeChar,Token2,TokenEscapeChar,Token7
     =  TokenEscapeChar,Token12," against",TokenEscapeChar,Token2,"p"
     =  "assword ",TokenEscapeChar,Token7,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " initialises the current (or given) file server for your use."
         ;=       " Your user name and password are checked by the file"
         ;=       " server against the password file.", 13
Logon_Syntax
         ;=       "Syntax: *Logon"
     =  "Syntax: *Logon [[:]<sta",TokenEscapeChar,Token9," "
     =  TokenEscapeChar,Token13,">|:<File",TokenEscapeChar,Token12," "
     =  TokenEscapeChar,Token11,">] <user ",TokenEscapeChar,Token11,">"
     =  " [[:<CR>]<Password>]",  0
         ;=       " [[:]<station number>|:<File server name>] <user name> "
         ;=       "[[:<CR>]<Password>]", 0

Pass_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," changes your password on"
     =  TokenEscapeChar,Token2,TokenEscapeChar,Token7
     =  TokenEscapeChar,Token12,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " changes your password on the file server.", 13
Pass_Syntax
         ;=       "Syntax: *Pass [<Old password> [<New password>]]", 0
     =  "Syntax: *Pass [<Old password> [<New password>]]",  0

ConfigureFS_Help
         ;=       "*Configure FS sets the default number or name for the file server.  "
     =  TokenEscapeChar,Token10,"FS ",TokenEscapeChar,Token19
     =  TokenEscapeChar,Token8,TokenEscapeChar,Token13," or "
     =  TokenEscapeChar,Token11," for",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token7,TokenEscapeChar,Token12,".  This "
     =  TokenEscapeChar,Token11," will be used when"
     =  TokenEscapeChar,Token2,"first *Logon command"
     =  TokenEscapeChar,Token41,"issued if it does not explicitly quo"
     =  "te either a ",TokenEscapeChar,Token11," or a "
     =  TokenEscapeChar,Token13,".", 13
         ;=       "This name will be used when the first *Logon command is issued if it "
         ;=       "does not explicitly quote either a name or a number.", 13
ConfigureFS_Syntax
         ;=       "Syntax: *Configure FS <station number>|<file server name>", 0
     =  "Syntax: ",TokenEscapeChar,Token10,"FS <sta"
     =  TokenEscapeChar,Token9," ",TokenEscapeChar,Token13,">|<"
     =  TokenEscapeChar,Token7,TokenEscapeChar,Token12," "
     =  TokenEscapeChar,Token11,">",  0

ConfigureLib_Help
         ;=       "*Configure Lib 0 will mean that logon will select the "
     =  TokenEscapeChar,Token10,"Lib 0 will mean that logon will sele"
     =  "ct",TokenEscapeChar,Token2,TokenEscapeChar,Token8
     =  TokenEscapeChar,Token35,", if it exists.  "
     =  TokenEscapeChar,Token10,"Lib 1 means that"
     =  TokenEscapeChar,Token2,TokenEscapeChar,Token35," 'ArthurLi"
     =  "b' will be selected at logon.", 13
         ;=       "default library, if it exists.  *Configure Lib 1 means "
         ;=       "that the library 'ArthurLib' "
         ;=       "will be selected at logon.", 13

ConfigureLib_Syntax
         ;=       "Syntax: *Configure Lib <0|1>", 0
     =  "Syntax: ",TokenEscapeChar,Token10,"Lib <0|1>",  0
        ] ; international_help

        [       :LNOT: ReleaseVersion
NetFS_FCBs_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," shows",TokenEscapeChar,Token2,"i"
     =  "nternal details of every open ",TokenEscapeChar,Token37,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " shows the internal details of every open object.", 13
NetFS_FCBs_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       0
NetFS_Contexts_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," shows",TokenEscapeChar,Token2,"i"
     =  "nternal details of every valid context.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " shows the internal details of every valid context.", 13
NetFS_Contexts_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token1,  0
         ;=       TokenEscapeChar,Token0
         ;=       0
        ]

        ALIGN

        END
