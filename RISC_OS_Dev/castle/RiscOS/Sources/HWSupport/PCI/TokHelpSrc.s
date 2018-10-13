     TTL ==> s.TokHelpSrc

 SUBT => PCI.HelpTexts


  [ International_Help <> 0

HelpForStarPCIDevices    ;=       "HPCIDEV",0
     =  "HPCIDEV",  0
SyntaxOfStarPCIDevices   ;=       "SPCIDEV",0
     =  "SPCIDEV",  0

HelpForStarPCIInfo       ;=       "HPCIINF",0
     =  "HPCIINF",  0
SyntaxOfStarPCIInfo      ;=       "SPCIINF",0
     =  "SPCIINF",  0

  |

HelpForStarPCIDevices
         ;=       "*", TokenEscapeChar,Token0
     =  "*",TokenEscapeChar,Token0," gives informa"
     =  TokenEscapeChar,Token9," about PCI devices installed in"
     =  TokenEscapeChar,Token2,"computer.", 13
         ;=       " gives information about PCI devices"
         ;=       " installed in the computer.", 13
SyntaxOfStarPCIDevices
         ;=       "Syntax: *", TokenEscapeChar,Token0
     =  TokenEscapeChar,Token1,  0
         ;=       0

HelpForStarPCIInfo
         ;=       "*", TokenEscapeChar,Token0
     =  "*",TokenEscapeChar,Token0," gives detailed informa"
     =  TokenEscapeChar,Token9," about a given PCI device.", 13
         ;=       " gives detailed information about a"
         ;=       " given PCI device.", 13
SyntaxOfStarPCIInfo
         ;=       "Syntax: *", TokenEscapeChar,Token0,
     =  TokenEscapeChar,Token1,"<PCI func",TokenEscapeChar,Token9," "
     =  "handle>",  0
         ;=       "<PCI function handle>"
         ;=       0

  ]

        END
