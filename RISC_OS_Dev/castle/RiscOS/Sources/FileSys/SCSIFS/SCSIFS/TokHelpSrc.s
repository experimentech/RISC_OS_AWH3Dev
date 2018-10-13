     TTL ==> s.TokHelpSrc

;>HelpText

 [ international_help
SCSI_Help             DCB "HFS", 0
SCSI_Syntax           DCB "SFS", 0
   [ DoBuffering
SCSIFSBuffers_Help    DCB "HBu", 0
SCSIFSBuffers_Syntax  DCB "SBu", 0
   ]
SCSIFSDirCache_Help   DCB "HDC", 0
SCSIFSDirCache_Syntax DCB "SDC", 0
SCSIFSDrive_Help      DCB "HDr", 0
SCSIFSDrive_Syntax    DCB "SDr", 0
 |
SCSI_Help
  ;= "*"
     =  "*",TokenEscapeChar,Token0," selects",TokenEscapeChar,Token2
     =  "SCSIFS as",TokenEscapeChar,Token2,TokenEscapeChar,Token5," "
     =  TokenEscapeChar,Token4,".", 13
  ;= TokenEscapeChar,Token0
  ;= " selects the SCSIFS as the current filing system.",13
SCSI_Syntax
  ;= "Syntax: *"
     =  TokenEscapeChar,Token1,  0
  ;= TokenEscapeChar,Token0
  ;= 0

   [ DoBuffering
SCSIFSBuffers_Help
  ;= "*Configure "
     =  TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  TokenEscapeChar,Token19,TokenEscapeChar,Token13," of extra "
     =  "1024 byte ",TokenEscapeChar,Token7," buffers taken by"
     =  TokenEscapeChar,Token2,"SCSIFS",TokenEscapeChar,Token40,"sp"
     =  "eed up opera",TokenEscapeChar,Token9,"s on open "
     =  TokenEscapeChar,Token7,"s. A value of 1 selects"
     =  TokenEscapeChar,Token2,TokenEscapeChar,Token8
     =  TokenEscapeChar,Token13," of buffers for",TokenEscapeChar,Token2
     =  "RAM size,",TokenEscapeChar,Token16,"0 disables fast buffering"
     =  ".", 13
  ;= TokenEscapeChar,Token0
  ;= " sets the number of extra 1024 byte file buffers taken by the SCSIFS to speed up operations on open files. A value of 1 selects the default number of buffers for the RAM size, and 0 disables fast buffering.",13
SCSIFSBuffers_Syntax
  ;= "Syntax: *Configure "
     =  "Syntax: ",TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  "<buffers>",  0
  ;= TokenEscapeChar,Token0
  ;= " <buffers>",0
   ]

SCSIFSDirCache_Help
  ;= "*Configure "
     =  TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  TokenEscapeChar,Token19,"size of",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token3,"y cache (in Kbytes) used by"
     =  TokenEscapeChar,Token2,"SCSIFS. A value of 0 selects a "
     =  TokenEscapeChar,Token8,"value which depends on RAM size.", 13
  ;= TokenEscapeChar,Token0
  ;= " sets the size of the directory cache (in Kbytes) used by the SCSIFS. A value of 0 selects a default value which depends on RAM size.",13
SCSIFSDirCache_Syntax
  ;= "Syntax: *Configure "
     =  "Syntax: ",TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  "<size>[K]",  0
  ;= TokenEscapeChar,Token0
  ;= " <size>[K]",0

SCSIFSDrive_Help
  ;= "*Configure "
     =  TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  TokenEscapeChar,Token19,"value",TokenEscapeChar,Token2
     =  TokenEscapeChar,Token8,"drive",TokenEscapeChar,Token41,"ini"
     =  "tialised",TokenEscapeChar,Token40,"for SCSIFS.", 13
  ;= TokenEscapeChar,Token0
  ;= " sets the value the default drive is initialised to for SCSIFS.",13
SCSIFSDrive_Syntax
  ;= "Syntax: *Configure "
     =  "Syntax: ",TokenEscapeChar,Token10,TokenEscapeChar,Token0," "
     =  "<drive>",  0
  ;= TokenEscapeChar,Token0
  ;= " <drive>",0
 ]
        ALIGN

        LNK     MsgCode.s
