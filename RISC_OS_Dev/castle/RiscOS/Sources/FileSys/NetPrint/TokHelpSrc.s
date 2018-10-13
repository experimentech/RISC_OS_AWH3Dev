     TTL ==> s.TokHelpSrc

        SUBT Strings for Help messages. => &.Arthur.NetPrint.HelpTexts

 [ international_help

SetPS_Help               ;= "HNPRSPS",0
     =  "HNPRSPS",  0
SetPS_Syntax             ;= "SNPRSPS",0
     =  "SNPRSPS",  0

PS_Help                  ;= "HNPRPS",0
     =  "HNPRPS",  0
PS_Syntax                ;= "SNPRPS",0
     =  "SNPRPS",  0

ListPS_Help              ;= "HNPRLPS",0
     =  "HNPRLPS",  0
ListPS_Syntax            ;= "SNPRLPS",0
     =  "SNPRLPS",  0

ConfigurePS_Help         ;= "HNPRCPS",0
     =  "HNPRCPS",  0
ConfigurePS_Syntax       ;= "SNPRCPS",0
     =  "SNPRCPS",  0

SyntaxOnlyOfConfigurePS  ;= "ConfPS", 0
     =  "ConfPS",  0

 |

SetPS_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," changes",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token5," ",TokenEscapeChar,Token26,"r"
     =  TokenEscapeChar,Token12," ",TokenEscapeChar,Token11," or "
     =  TokenEscapeChar,Token13,".  If no argument"
     =  TokenEscapeChar,Token41,"supplied",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token5," setting reverts"
     =  TokenEscapeChar,Token40,"the initialised state"
     =  TokenEscapeChar,Token16,"will use configured state if"
     =  TokenEscapeChar,Token2,"next open (or save) does not explici"
     =  "tly quote either a ",TokenEscapeChar,Token11," or a "
     =  TokenEscapeChar,Token13, 13
         ;=       TokenEscapeChar,Token0
         ;=       " changes the current printer server name or number.  "
         ;=       "If no argument is supplied the current setting reverts "
         ;=       "to the initialised state and will use configured state "
         ;=       "if the next open (or save) does not explicitly quote "
         ;=       "either a name or a number", 13
SetPS_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"<",TokenEscapeChar,Token26,"r"
     =  TokenEscapeChar,Token12," ",TokenEscapeChar,Token11,">|<sta"
     =  TokenEscapeChar,Token9," ",TokenEscapeChar,Token13,">]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [<printer server name>|<station number>]", 0

PS_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," selects new "
     =  TokenEscapeChar,Token8,TokenEscapeChar,Token26,"r"
     =  TokenEscapeChar,Token12," for",TokenEscapeChar,Token2,"next"
     =  " use of",TokenEscapeChar,Token2,TokenEscapeChar,Token26,"r"
     =  TokenEscapeChar,Token12,".  If no argument"
     =  TokenEscapeChar,Token41,"supplied",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token5," ",TokenEscapeChar,Token26,"r"
     =  TokenEscapeChar,Token12," ",TokenEscapeChar,Token11," and/or"
     =  " ",TokenEscapeChar,Token13," are ",TokenEscapeChar,Token26,"d"
     =  " out, along with",TokenEscapeChar,Token2,"status of that"
     =  TokenEscapeChar,Token12,".", 13
         ;=       TokenEscapeChar,Token0
         ;=       " selects new default printer server for the next "
         ;=       "use of the printer server.  If no argument is supplied "
         ;=       "the current printer server name and/or number are "
         ;=       "printed out, along with the status of that server.", 13
PS_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"<",TokenEscapeChar,Token26,"r"
     =  TokenEscapeChar,Token12," ",TokenEscapeChar,Token11,">|<sta"
     =  TokenEscapeChar,Token9," ",TokenEscapeChar,Token13,">]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [<printer server name>|<station number>]", 0

ListPS_Help
         ;=       "*"
     =  "*",TokenEscapeChar,Token0," shows",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token11,"s of",TokenEscapeChar,Token38,"the "
     =  TokenEscapeChar,Token5,"ly available ",TokenEscapeChar,Token26
     =  "r",TokenEscapeChar,Token12,"s.  If",TokenEscapeChar,Token2,"o"
     =  "p",TokenEscapeChar,Token9,"al argument",TokenEscapeChar,Token41
     =  "supplied then",TokenEscapeChar,Token2,"status of each"
     =  TokenEscapeChar,Token12," will also be displayed.", 13
         ;=       TokenEscapeChar,Token0
         ;=       " shows the names of all the currently available printer "
         ;=       "servers.  If the optional argument is supplied then the "
         ;=       "status of each server will also be displayed.", 13
ListPS_Syntax
         ;=       "Syntax: *"
     =  TokenEscapeChar,Token30,"-full]",  0
         ;=       TokenEscapeChar,Token0
         ;=       " [-full]", 0

ConfigurePS_Help
         ;=       "*Configure PS sets the default name or number for the "
     =  TokenEscapeChar,Token10,"PS ",TokenEscapeChar,Token19
     =  TokenEscapeChar,Token8,TokenEscapeChar,Token11," or "
     =  TokenEscapeChar,Token13," for",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token26,"r",TokenEscapeChar,Token12,". This "
     =  TokenEscapeChar,Token11," or ",TokenEscapeChar,Token13," wil"
     =  "l be used if",TokenEscapeChar,Token2,"first open (or save) d"
     =  "oes not explicitly quote either a ",TokenEscapeChar,Token11," "
     =  "or a ",TokenEscapeChar,Token13, 13
         ;=       "printer server. This name or number will be used if "
         ;=       "the first open (or save) does not explicitly quote "
         ;=       "either a name or a number", 13
ConfigurePS_Syntax
         ;=       "Syntax: *Configure "
     =  "Syntax: ",TokenEscapeChar,Token10
 [ :LNOT: UseMsgTrans
SyntaxOnlyOfConfigurePS
 ]
         ;=       "PS", 31, 31, 31, 31, 31, 31, 31, 31, 31, "<printer server name>|<station number>", 0
     =  "PS", 31, 31, 31, 31, 31, 31, 31, 31, 31,"<"
     =  TokenEscapeChar,Token26,"r",TokenEscapeChar,Token12," "
     =  TokenEscapeChar,Token11,">|<sta",TokenEscapeChar,Token9," "
     =  TokenEscapeChar,Token13,">",  0

 [ UseMsgTrans
SyntaxOnlyOfConfigurePS  ;= "ConfPS", 0
     =  "ConfPS",  0
 ]

 ]

        ALIGN
        END
