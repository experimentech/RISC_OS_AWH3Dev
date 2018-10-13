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
progerrslist
       
        MACRO
        ProgErr $n,$t,$l
        DCD     ErrorNumber_$n
        MEND


        ProgErr BadModuleReason, "BadModuleReason:Unknown OS_Module call"
        ProgErr BadDynamicArea, "BadDynamicArea:Unknown dynamic area", ErrorNumber_BadModuleReason
        ProgErr BadRMHeaderField, "BadRMHeaderField:Illegal header field in module"
        ProgErr StackFull,    "StackFull:No room on supervisor stack"
        ProgErr HeapBadReason,      "HeapBadReason:Bad reason code"
        ProgErr HeapFail_Init,      "HeapFailInit:Can't initialise heap"
        ProgErr HeapFail_BadDesc,   "BadDesc:Bad heap descriptor"
        ProgErr HeapFail_BadLink,   "BadLink:Heap corrupted"
        ProgErr HeapFail_NotABlock, "NotABlock:Not a heap block"
        ProgErr HeapFail_BadExtend, "BadExtend:No RAM for extending heap"
        ProgErr HeapFail_ExcessiveShrink, "ExcessiveShrink:Can't shrink heap any further"
        ProgErr HeapFail_HeapLocked,"Heap Manager busy" 
        ProgErr BadClaimNum, "BadClaimNum:Bad vector number"
        ProgErr NaffRelease, "NaffRelease:Bad vector release"
        ProgErr NaffDevNo,   "NaffDevNo:Bad device number"
        ProgErr BadDevVecRel,"BadDevVecRel:Bad device release" 
        ProgErr BadEnvNumber, "BadEnvNumber"    ; wally environment parameter number
        ProgErr WimpNoClaim,       "NoClaim"        ;"Wimp unable to claim work area"
        ProgErr WimpBadOp,         "BadOp"          ;"Invalid Wimp operation in this context"
        ProgErr WimpRectFull,      "RectFull"       ;"Rectangle area full"
;        ProgErr WimpTooBig,        "TooBig"         ;"Window definition won't fit"
        ProgErr WimpGetRect,       "GetRect"        ;"Get_Rectangle not called correctly"
        ProgErr WimpBadHandle,     "BadHandle"      ;"Illegal window handle"
        ProgErr WimpBadExtent,     "BadExtent"      ;"Bad work area extent"
        ProgErr WimpNoTemplateFile,"NoTemplateFile" ;"Template file not found"
        ProgErr WimpBadTemplate,   "BadTemplate"    ;"Template entry invalid"
        ProgErr WimpBadFonts,      "BadFonts"       ;"Unable to bind font handle"
        ProgErr WimpBadSyntax,     "BadSyntax"      ;"Syntax error in validation string"
        ProgErr WimpNoTemplate,    "NoTemplate"     ;"Template entry not found"
;        ProgErr WimpBadPalFile,    "BadPalFile"     ;"Error in palette file"
        ProgErr WimpBadVersion,    "BadVersion"     ;"Bad version number passed to Wimp_Initialise"
        ProgErr WimpBadMessageSize,"BadMessageSize" ;"Message block is too big / not a multiple of 4"
        ProgErr WimpBadReasonCode, "BadReasonCode"  ;"Illegal reason code given to SendMessage"
        ProgErr WimpBadTaskHandle, "BadTaskHandle"  ;"Illegal task handle"
        ProgErr WimpCantTask,      "CantTask"       ;"Can't start task from here"
        ProgErr WimpBadSubMenu,    "BadSubMenu"     ;"Submenus require a parent menu tree"
        ProgErr WimpOwnerWindow,   "OwnerWindow"    ;"Access to window denied"
        ProgErr WimpBadTransfer,   "BadTransfer"    ;"Wimp transfer out of range"
        ProgErr WimpBadSysInfo,    "BadSysInfo"     ;"Bad parameter passed to Wimp in R0"
        ProgErr WimpBadPtrInR1,    "BadPtrInR1"     ;"Bad pointer passed to Wimp in R1"
        ProgErr WimpBadEscapeState,"BadEscapeState" ;"Wimp_Poll called with escape enabled!"
        ProgErr WimpBadIconHandle, "BadIconHandle"  ;"Illegal icon handle"
        ProgErr TemplateEOF,       "TemplateEOF"    ;"End of file while reading template file."
        ProgErr CDATStackOverflow,    "CDATStackOverflow:Stack overflow"
        ProgErr CDATBufferOverflow,   "CDATBufferOverflow:Buffer overflow"
        ProgErr CDATBadField,         "CDATBadField:Unknown '%' field"
        ProgErr NetFSVectorCorrupt,   "Unable to release, not top entry in NetFS entry vector"
        ProgErr SWIVectorCorrupt,     "Unable to release, not top entry in SWI thread"
        ProgErr WorkspaceNotReleased, "Workspace not released"
        ProgErr FileSwitchNoClaim,    "Unable to claim FileSwitch workspace"
        ProgErr BadFSControlReason,   "Bad FSControl call"
        ProgErr BadOSFileReason,      "Bad OSFile call"
        ProgErr BadOSArgsReason,      "Bad OSArgs call"
        ProgErr BadOSGBPBReason,      "Bad OSGBPB call"
        ProgErr BadModeForOSFind,     "Bad mode for OSFind"
        ProgErr NoRoomForTransient,   "No room to run transient"
        ProgErr ExecAddrNotInCode,    "Execution address not within code"
        ProgErr ExecAddrTooLow,       "Code runs too low"
        ProgErr UnalignedFSEntry,     "Unaligned filing system entry point"
        ProgErr UnsupportedFSEntry,   "Filing system does not support this operation"
        ProgErr FSNotSpecial,         "Filing system does not support special fields"
        ProgErr CoreNotReadable,      "No readable memory at this address"
        ProgErr CoreNotWriteable,     "No writable memory at this address"
        ProgErr BadBufferSizeForStream, "Bad buffer size"
        ProgErr InvalidErrorBlock,    "Invalid error block"
        ProgErr InconsistentHandleSet,  "Inconsistent handle set"
;        ProgErr MultiFSDoesNotSupportGBPB11, "The OS_GBPB 11 call is not supported by MultiFS images"
        ProgErr TooManyErrorLookups,  "Too many error lookups happening at once - recursion assumed"
        ProgErr Sprite_NoWorkSpace,         "SNoWorkSpace:No sprite memory", 128
        ProgErr Sprite_NoRoom,              "SNoRoom:No room to get sprite", 130
        ProgErr Sprite_NoSprites,           "NoSprites:No sprites", 131
        ProgErr Sprite_NotGraphics,         "NotGraphics:Not a graphics mode", 129
        ProgErr Sprite_NotEnoughRoom,       "SNotEnoughRoom:Not enough room", 133
        ProgErr Sprite_BadSpriteFile,       "SBadSpriteFile:Bad sprite file"
        ProgErr Sprite_NoRoomToMerge,       "SNoRoomToMerge:Not enough room to add sprite"
        ProgErr Sprite_Bad2ndPtr,           "SBad2ndPtr:Bad 2nd ptr"
        ProgErr Sprite_InvalidRowOrCol,     "InvalidRowOrCol:Invalid row or column"
        ProgErr Sprite_InvalidHeight,       "InvalidHeight:Invalid height"
        ProgErr Sprite_InvalidWidth,        "InvalidWidth:Invalid width"
        ProgErr Sprite_NoRoomToInsert,      "NoRoomToInsert:Not enough memory to insert sprite row or column"
;        ProgErr Sprite_SpriteAlreadyExists, "SpriteAlreadyExists:Sprite already exists"
        ProgErr Sprite_InvalidSpriteMode,   "InvalidSpriteMode:Invalid sprite mode"
        ProgErr Sprite_BadReasonCode,       "SBadReasonCode:Bad sprite reason code"
        ProgErr Sprite_CantDoSystem,        "System sprites not allowed here"
        ProgErr Sprite_BadTranslation,      "Bad colour translation table"
        ProgErr Sprite_BadGreyScale,        "Grey-scale only does 16 colours"
        ProgErr Sprite_BadPointerShape,     "Unsuitable sprite for SetPointerShape"
        ProgErr Sprite_BadAppend,           "Can't append sprite"
        ProgErr Sprite_CantInTeletext,      "CantInTeletext:Can't switch output in teletext mode"
        ProgErr Sprite_InvalidSaveArea,     "SInvalidSaveArea:Invalid save area"
        ProgErr Sprite_SpriteIsCurrentDest, "SpriteIsCurrentDest:Sprite is current destination"
        ProgErr Sprite_BadFlags,            "Attempt to set reserved flags"
        ProgErr Sprite_BadCoordBlock,       "Source rectangle not inside sprite"
        ProgErr Sprite_BadSourceRectangle,  "Source rectangle area zero"
        ProgErr Sprite_BadTransformation,   "SpriteExtend can only do linear transformations"
        ProgErr Sprite_BadDepth,            "Unable to plot sprites of this format"
        ProgErr Sprite_BadSwitchDepth,      "Cannot switch output to sprites of this format"
;        ProgErr Sprite_NoMaskOrPaletteAllowedInThisDepth, "Mask or Palette operations not supported in this display depth"
        ProgErr Sprite_BadDPI,              "BadDPI:Illegal XDPI or YDPI in sprite"
       ProgErr NoDrawInIRQMode,       "Draw module does not work in IRQ mode"
       ProgErr BadDrawReasonCode,     "Bad Draw_ProcessPath reason code"
       ProgErr ReservedDrawBits,      "Reserved bits not zero"
       ProgErr InvalidDrawAddress,    "Invalid address"
       ProgErr BadPathElement,        "Bad path element"
       ProgErr BadPathSequence,       "Path elements out of order"
       ProgErr MayExpandPath,         "Operation may change path length"
       ProgErr PathFull,              "Output path full"
       ProgErr PathNotFlat,           "Path needs to be flattened"
       ProgErr BadCapsOrJoins,        "Invalid cap and join specification"
       ProgErr TransformOverflow,     "Overflow while transforming point"
       ProgErr DrawNeedsGraphicsMode, "Draw can only plot to graphics modes"
       ProgErr NoSuchDrawSWI,         "No such Draw SWI", ErrorNumber_NoSuchSWI
       ProgErr UnimplementedDraw,     "Facility not in this version of Draw"
       ProgErr CTBadCalib,           "Bad calibration table"
       ProgErr CTConvOver,           "Overflow in conversion"
       ProgErr CTBadHSV,             "Hue should be undefined in achromatic colours"
       ProgErr CTSwitched,           "Not whilst output switched to sprite"
       ProgErr CTBadMiscOp,          "Unknown MiscOp call"
       ProgErr CTBadFlags,           "Reserved fields must be zero"
       ProgErr CTBuffOver,           "Buffer too small to read palette into"
       ProgErr CTBadDepth,           "Not supported in this display depth"
       ProgErr TaskWindow_BadSWIEntry,   "Can't restore SWI table properly"
       ProgErr TaskWindow_BadTaskHandle, "Bad task or text handle"
       ProgErr TaskWindow_Dying,         "Task dying"
       ProgErr TaskWindow_NoRedirection, "Kernel does not support OS_ChangeRedirection"
       ProgErr NetFSInternalError,    "Fatal internal error"
       ProgErr NetPrintInternalError,    "Fatal internal error"
       ProgErr BadSoundIRQClaim,"Sound Level0 failed to claim IRQ vector"
       ProgErr BadSound1Init,"Unable to claim sufficient Sound Level 1 heap space"
       ProgErr BadSound2Init,"Unable to claim sufficient Sound Level 2 heap space"
       ProgErr BadVoiceInit,"Unable to claim sufficient Sound Voice heap space"
       ProgErr SCSI_FailClaim,"SCSI failed to allocate required RAM at initialise"
       ProgErr SCSI_IDLost,"The SBIC has lost it's SCSI ID"
       ProgErr SCSI_SBICBusy,"The SBIC is busy performing a command"
       ProgErr SCSI_PanicMess,"Panic - the SBIC has lost track of things"
       ProgErr SCSI_CheckAux,"Check Aux register"
       ProgErr SCSI_MegaText,"An error or situation that is undefined has occurred"
       ProgErr Video_FailClaim,"Video failed to claim its workspace"
       ProgErr Video_BadVpError,"Parameter to VP must be 1 to 5 or X"
       ProgErr Video_BadFcodeError,"Bad f-code"
       ProgErr Video_BadSpeedError,"Bad speed parameter"
       ProgErr IIC_NoAcknowledge,"No acknowledge from IIC device"

        DCD     -1

        END
