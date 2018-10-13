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
; > Sources.Wimp01

;;----------------------------------------------------------------------------
;; Window Manager module
;;
;; *********************
;; ***  CHANGE LIST  ***
;; *********************
;;
;; 28-Jul-87    0.17    Change list added
;; 28-Jul-87            Wimp defines its own soft characters
;;                      KEY CODES -- New values returned (use *FX221,2 etc.)
;;              0.18    Wimp icons allow Shift-Arrowdebugsw etc.
;; 29-Jul-87            Wimp_CloseDown added
;;                      Wimp restores *FX 221 etc. status on exit
;;                      Introduce 'MySWI' macro
;;              0.18    Implement 'page up/down' in scroll bars
;; 30-Jul-87    0.19    Fiddle with OS_ChangeEnvironment (multi-tasking)
;;                      Put in bulk of multi-tasking code
;;  3-Aug-87            Put in conditional assembly so I can make Wimp 0.18
;;                      Make Wimp mode-indipendant
;;              0.19    Fix quit handling so Wimp exits correctly
;;  4-Aug-87    0.19    Don't replace quit handler if it's me anyway
;;                      Fix bug in dragbox - reset dotdash if get_rectangle
;;  5-Aug-87    0.19    Release non-tasking version of Wimp 0.19
;;              0.20    Make Wimp read size of screen window limits
;; 18-Aug-87            Re-initialise Wimp on soft-break
;; 19-Aug-87    0.21    Allow multiple sprite areas within a window
;;                      Implement new window flags for border bits
;; 20-Aug-87            Allow compatibility between old & new border flags
;;                      Fix bug in Create_Menu (menucaretwindow)
;; 21-Aug-87            Convert to use SWI XOS_Plot
;; 24-Aug-87            Invent new button type (writeable + notify)
;;                      Fix buglet in Open_Window (didn't use dx,dy)
;; 25-Aug-87            Fix mode 22 pointer and VDU 5 caret
;; 26-Aug-87    0.21a   Fix bug: windows get bigger in mode 22!
;;  1-Sep-87            Fix bug: drag box with 'trespass' windows
;;                      Make double-click check distance moved by mouse
;;  3-Sep-87    0.22    Allow variable caret colour (bit set in 'height')
;; 14-Sep-87    1.00    Release Wimp 1.00
;; 28-Sep-87    1.01    Fix bug: immoveable window disallowed all drags
;; 28-Sep-87            Fix bug: woggles wrong icon if menu arrow selected
;; 28-Sep-87            Fix bug: toggle icon not redrawn if window doesn't move
;; 28-Sep-87            Fix bug: if window moving, don't reset toggled state
;;  2-Oct-87            Make Wimp border size vary with pixel size
;; 22-Oct-87            Fix bug: task restarting should close menus
;; 29-Oct-87    1.21    Add SWI Wimp_ReportError
;; 30-Oct-87            Change Wimp_CloseDown so it doesn't take control away
;; 30-Oct-87            Fiddle about with error reporting in multi-tasking
;;  2-Nov-87            Implement Wimp_TaskHandle
;;  3-Nov-87            Remove Wimp_TaskHandle
;;  9-Nov-87            Fix bug: pagehoriz goes to wrong bhandle
;; 19-Nov-87    1.22    Make Wimp_SetExtent not reset the 'toggled' state
;; 25-Nov-87    1.30    Implement validation strings
;; 25-Nov-87            Fix bug: Wimp_GetPointerInfo returned 1 word too many
;; 26-Nov-87            Add SWI Wimp_GetWindowOutline
;;  2-Dec-87            Change Wimp_Initialise so task handle is in R1 on exit
;;  2-Dec-87            Wimp_Initialise: R0 on entry = latest known Wimp
;;  2-Dec-87            Fix bug: Wimp_CloseDown checked wrong task index
;;  2-Dec-87            Fix bug: Wimp_Poll deleted task incarnation number
;;  3-Dec-87            Sort out Wimp_CloseDown - turns pointer off etc.
;;  3-Dec-87            Change sprite icon plotting so fg colour is set up
;;  9-Dec-87    1.31    Fix bug: *pointer set bbox to 0,0,1280,1024
;;  9-Dec-87            Change Wimp_Init: *Print <Wimp$Resources>.!Palette
;;                      initialise Wimp$Resources to adfs:% if not there
;; 31-Dec-87    1.32    Call ErrorV when Wimp_ReportError called
;; 10-Jan-88    1.33    Redefine only chars &80-&85, &88-&8B
;; 20-Jan-88            Implement persistent menus
;; 20-Jan-88            Implement scrollable icons (automatic)
;; 21-Jan-88    1.34    Implement SWI Wimp_PollIdle (R2 = target time)
;; 22-Jan-88            Implement SWI Wimp_PlotIcon (R1-->icon defn)
;; 25-Jan-88            Implement Wimp colour lookup table & assoc. SWIs
;; 25-Jan-88            Change Wimp_Init: *<Wimp$Resources>.!Palette
;;                   ** changed again - palette held in Wimp itself
;;                   ** can be overridden before Wimp_Init, using *WimpPalette
;; 26-Jan-88            Implement palette table lookup
;; 26-Jan-88            Implement Wimp_SetMode
;; 27-Jan-88            Fix bug in Wimp_CloseDown (closes all tasks)
;; 28-Jan-88            Implement ECFs for Wimp monochrome modes
;; 28-Jan-88            Implement Wimp_SetPalette and Wimp_ReadPalette
;; 29-Jan-88            Change tasking so that taskcount can get to 0
;;                      (fixes bug: OS_Exit called without Wimp_CloseDown)
;; 29-Jan-88            Implement Wimp_SetColour
;;  1-Feb-88            Implement 'back window' for old-style Wimp_Init
;;  1-Feb-88            Extend window area to cover whole screen
;;  1-Feb-88            Make GetPointerInfo return handle -1 if backwindow
;;                   ** cancelled - now Ptr_Entering/Leaving is bodged instead
;;  2-Feb-88            Make OpenWindow remove dragbox first
;;  2-Feb-88            Make single-tasking progs get exclusive use of Wimp
;;  2-Feb-88            Single-tasking progs don't have mode/palette set up
;;  2-Feb-88            Remove Wimp's default UnusedSWI handler
;;  2-Feb-88            Allow window to have NO borders
;;                      (wf_newformat=1 and wf_iconbits = 0)
;;                   ** changed so that w_tfcol=255 forces that
;;  3-Feb-88            Fix bug in Wimp_Init : single task palette is 1:1
;;  3-Feb-88            Check that 200 <= R0 <= 10000 on entry to Wimp_Init
;;  3-Feb-88            Do soft key expansion inside Wimp_ProcessKey
;;  8-Feb-88            Implement Wimp_SendMessage
;;  9-Feb-88            Ignore errors from soft key expansion
;;  9-Feb-88            Added WimpCantKill error message in Die routine
;;  9-Feb-88            Change message poll codes to 17..19
;;  9-Feb-88            Implement Lose_Caret and Gain_Caret reason codes
;; 11-Feb-88    1.35    Change task data storage to use the RMA
;; 15-Feb-88            Implement common sprite area for Wimp programs
;;                        (*IconSprites, MergeSpriteFile and BaseOfSprites)
;; 16-Feb-88            Check that parent task is alive in Wimp_StartTask
;; 16-Feb-88            Implement Wimp_BlockCopy
;; 17-Feb-88            Allow window/areaCBptr=1 ==> use common sprite area
;; 18-Feb-88            Implement iconbar create/delete icon & auto-scrolling
;; 19-Feb-88            Change escape handling so CHR$(27) is used
;; 19-Feb-88            Implement *Desktop command & allow Wimp to be RMRun
;; 25-Feb-88    1.36    Change Wimp_CloseDown: no cls with old tasks
;; 25-Feb-88            Make Wimp SWIs preserve flags unless V set on exit
;; 25-Feb-88            Implement Wimp_SlotSize
;; 25-Feb-88    1.40    Implement Switcher!
;; 25-Feb-88            Change window flags: title fg=255 ==> no borders at all
;; 25-Feb-88            Make error box bigger
;; 25-Feb-88            Add WimpBadSubMenu error (no parent tree)
;;  1-Mar-88            Change palette initialisation so it's done at Init time
;;                      - also, *WimpPalette only affects table if no tasks
;;  2-Mar-88            Implement Wimp_ReadPixTrans
;;  2-Mar-88            Selectively disallow Wimp SWIs depending on context
;;                      - change 'MySWI' macro to allow this
;;                      Disallow non-owner access to windows in some cases
;;  2-Mar-88            Implement UpCall trapping (disc prompting)
;;  2-Mar-88            Use Wimp$Path for OpenTemplate (can't MergeSpriteFile)
;;                      - removed - modules use 'Wimp:' to get it
;;  2-Mar-88            Wimp$Path set up in init code to DeskFS:,
;;                      - removed - Desktop module is responsible
;;  2-Mar-88            Implement 'mode changed' message from Wimp
;;  2-Mar-88            Change scroll bar code to use MUL, and avoid overflow
;;  3-Mar-88    1.41    Change structure so handlers are swapped in pagetask
;;                      - crashes if handlers called while memory not there!
;;  3-Mar-88            Intercept ChangeEnvironmentV to check on handlers
;;                      - allows Wimp to replace 1st task's handlers
;;  3-Mar-88            Avoid ECFs when restoring the screen on CloseDown
;;  3-Mar-88            Make Wimp remember 'current mode' for restoring
;;  3-Mar-88            Disallow Wimp_Init if Quit handler is inserted
;;                      -eg Twin can't run another Wimp task if run from Wimp
;;  3-Mar-88            Allow Wimp_SetMode when no tasks running (just set var)
;;  3-Mar-88            Implement *configure wimpmode and *wimpmode
;;  4-Mar-88            Claim/release vectors properly on soft reset
;;  4-Mar-88            Remove *WimpMode command (only *Configure WimpMode)
;;  4-Mar-88            Fix bug: MergeSpriteFile doesn't check 'not found'
;;  4-Mar-88            Move mode variable checking to Service call handler
;;  5-Mar-88    1.42    EOR CMOS mode with 12 so that is he default
;;  5-Mar-88            Issue Service_StartedWimp when *desktop finished
;;  7-Mar-88            Fix bug: exit to dead parent
;;  7-Mar-88            Put identifying message into error box
;;  7-Mar-88            Fix bug: Wimp_ProcessKey errors if no input focus
;;  7-Mar-88            Disallow non-graphic modes in Wimp_SetMode
;;  8-Mar-88            Put Wimp *commands in alphabetical order
;;  8-Mar-88            Fix caret so it's never outside the icon bounds
;;  8-Mar-88    1.43    Change window memory allocation to use RMA
;;  9-Mar-88            Put w_relhandle field into window definition
;;  9-Mar-88            Kill message queue when last task dies
;;  9-Mar-88            Allow user-supplied subroutine in Wimp_DragBox
;;  9-Mar-88            Fix caret: only subtract 1 from top (not dy)
;;                      - now compatible with old Wimps if icon big enough
;; 10-Mar-88            If waitdrag pending, drag immediately if icon changes
;; 10-Mar-88            Fix caret: always put 'knobs' on the top
;; 11-Mar-88            Add TaskInit/CloseDown messages from Wimp
;; 11-Mar-88            Move error messages so ADR works (use XError in macros)
;; 12-Mar-88            Implement WimpFlags and continuous dragging/scrolling
;; 14-Mar-88            Fix bug: deletemessagequeue frees blocks incorrectly
;; 14-Mar-88            Fix bug: use int_processkey to avoid re-entrancy
;; 15-Mar-88            Change Wimp_SlotSize so R0<0 ==> don't change value
;; 16-Mar-88    1.44    Set parentquithandler = address of code (not wsptr)
;;                      set it to 0 when starting a task (insist on new app.)
;; 17-Mar-88            Use OS_ReadDefaultHandler to set up ALL handlers
;;                      - removed for Arthur 1.37 since it doesn't work!
;; 17-Mar-88            Change text width/height using scaled characters
;; 17-Mar-88            Use Service_MemoryMoved to reshuffle page tables
;;                      Wimp claims CAOpointer on Wimp_Initialise
;;                      ---- version 2.04 - only done in OS_ChangeDynamicArea
;; 17-Mar-88            Change *Pointer to check for HiResMono properly
;; 17-Mar-88            Use 'tasknumber' to make task verion number global
;;                      - avoids problem: OS_GenerateError/Exit
;;                        means that a task doesn't know if it's been aborted
;;                        subsequent *RMkill kills the OLD task version no.
;; 17-Mar-88            Fix bug: wimpquithandler check should look at R1
;; 18-Mar-88            Check for applicationspacesize>memorylimit in findpgs
;; 18-Mar-88            Implement ChangeDynamicArea checking
;; 18-Mar-88            Change Die code so it doesn't call initptrs again
;; 21-Mar-88            Implement Wimp_ClaimFreeMemory
;; 22-Mar-88    1.45    Increase max number of windows to 64
;; 22-Mar-88    1.46    Fix bug: Wimp_SendMessage should ignore task version
;;                      Always try to send the message (unless illegal handle)
;;                      The message is only ignored later
;; 23-Mar-88            Implement OS_ChangeDynamicArea call to move memory
;;                        between application space and the free pool
;;                        - changed to be in Wimp_SlotSize
;; 23-Mar-88            Implement *WimpRun command
;; 23-Mar-88            Give source of *Desktop stuff to Tim & delete from Wimp
;; 24-Mar-88            Change Wimp_SlotSize so current slot can be altered
;; 24-Mar-88            Don't set Wimp$Path in Init code
;; 24-Mar-88            Change order of sethandlers/findpages
;;                      - what if BASIC was running when *desktop invoked?
;; 24-Mar-88            Load error/iconbar/back window from Wimp:Templates.Wimp
;;                      - do it when the first task initialises
;;                      - before setting up the handlers!
;; 25-Mar-88            Use pixtrans for 1- and 2-bpp sprite icons
;; 25-Mar-88            Fix bug in SendMessage (ack) - msb_ used instead of ms_
;; 25-Mar-88            Make Wimp load 'Wimp:Sprites.Wimp' on init (1st time)
;; 25-Mar-88    1.47    Change addtoiconbar so it copies the icon onto stack
;; 25-Mar-88            Fix bug: error box title wasn't indirected
;; 25-Mar-88    1.48    Fix bug: message 19 kills all message types now
;; 26-Mar-88            Fix bug: click in icon finds wrong text posn
;; 26-Mar-88            Change gaps at side of scroll bars
;; 28-Mar-88            Improve Wimp ecf patterns (for grey-scales)
;; 28-Mar-88            Make SendMessage to window -1 just lose the message
;; 28-Mar-88    1.49    Make ReportError switch output to screen
;; 28-Mar-88            Implement w_minxy word in window header
;; 29-Mar-88            Fix bug: 'addsub' rounds coords to pixel boundaries
;; 29-Mar-88            Fix bug: Wimp_ReportError should set text size
;; 29-Mar-88    1.50    Fix bug: ExitWimp set redrawhandle=nullptr if V set
;; 29-Mar-88            Implement call to set ecf origin in redraw/update
;; 30-Mar-88    1.51    Implement wf_grabkeys and Wimp_ProcessKey hierarchy
;; 30-Mar-88            Fix bug: intrect must round coords to pixels
;; 31-Mar-88    1.52    Start tasks up with escape enabled, then disable it
;; 31-Mar-88            Change pointerwindow so it only subtracts 1 from x1,y1
;; 31-Mar-88            Change graphicswindow similarly
;; 31-Mar-88            Force old-style tasks to have w_minx/y = 0
;;  3-Apr-88            Make text gap 6 OS units (not 3*dx)
;;  4-Apr-88            Implement *WimpSlot command (leave *WimpRun in for now)
;;  4-Apr-88            Put *Pointer command into Wimp_ReportError
;;  4-Apr-88            Exit Wimp_ReportError if <escape> pressed
;;  7-Apr-88            Make Wimp_ReportError invert the relevant icon
;;  7-Apr-88            Change max no of tasks to 32
;;  7-Apr-88    1.53    Allow icons to have text AND sprite bits set
;;  8-Apr-88            Implement if_halfsize (half-size sprites)
;;  9-Apr-88            Make Wimp_SendMessage use R2,R3 and return R2
;; 10-Apr-88            Issue Service_MouseTrap in menu selection code
;;                      - also in drag activation
;; 10-Apr-88            Drag window: only issue Open_Window if different
;; 11-Apr-88            Change iconbar window handle on exit to -2
;; 11-Apr-88    1.54    Make GetPointerInfo return -2 for iconbar window
;; 11-Apr-88    1.55    Remove 'Access to window denied' for IJack (netmon)
;; 12-Apr-88    1.56    Implement Wimp_CommandWindow (R0 --> title)
;; 13-Apr-88            Remove *WimpRun command
;; 13-Apr-88            Make Wimp_ReportError acknowledge escape
;; 13-Apr-88            Implement *WimpTask command for Desktop auto-boot
;; 13-Apr-88            Disallow toggled bit when creating a window
;; 13-Apr-88            Fix bug: Wimp_SetColour to pass on ecf action
;; 13-Apr-88            Use Wimp_CommandWindow when Wimp_StartTask starts
;; 13-Apr-88            Make Wimp more re-entrant (stack polltaskhandle etc.)
;; 13-Apr-88            When window/icon killed, delete messages if nec.
;; 13-Apr-88    1.57    Change back/quit box so click without release used
;; 14-Apr-88            Debounce Wimp_ReportError clicks better
;; 14-Apr-88    1.58    Grab pages from current slot on OS_ChangeDynamicArea
;; 14-Apr-88            Singletask errors to ReportError unless chars printed
;; 14-Apr-88            ReportError takes note of commandflag setting
;; 14-Apr-88            Implement Wimp_TextColour
;; 14-Apr-88            Use Wimp_TextColour to set command window colours
;; 14-Apr-88            Use Wimp_TextColour to set colours on exit from Wimp
;; 14-Apr-88            Allow ReadPalette etc. outside Wimp_Init
;; 15-Apr-88            Fix bug: recalcpalette AFTER taskcount increased
;; 15-Apr-88            Change Wimp Template/SendMessage so ROM is not written
;; 15-Apr-88            -------- Arthur 1.60 -----------
;; 18-Apr-88    1.61    Fix bug: drag returned for deleted window ==> exception
;; 19-Apr-88            Fix bug: checkversion AFTER error checks (singletaskh)
;; 19-Apr-88            Fix bug: reset pending flags if window deleted
;; 19-Apr-88            Treat Wimp_Poll as Wimp_PollIdle (0 timeout)
;; 21-Apr-88            Fix bug: *RMTidy causes Wimp not to re-initialise w/s
;; 21-Apr-88            Change CommandWindow so VDU 15 rather than 14
;; 22-Apr-88    1.62    Change Wimp_SlotSize so Message_SlotSize is issued
;; 22-Apr-88    1.63    Make ASCII 8 equivalent to 127 in writeable icons
;; 25-Apr-88            Change *Pointer and *IconSprites help text
;; 27-Apr-88            Fix bug: ExitPoll set redrawhandle=-1
;; 27-Apr-88            Change Wimp_ReportError so redrawhandle/rects are saved
;; 27-Apr-88    1.64    Change GetRect so it only re-validates redraw rects
;;                      (not update), and it does it at the start (not end)
;; 28-Apr-88            Further change it so bg clearing done in Get_Rectangle
;;                      YUK = false ==> new-style drawing
;; 29-Apr-88    1.65    Claim 24k block on init, shrinking it for each claim
;;  3-May-88    1.66    Fix bug: GetRectangle returned wrong clip window
;;  5-May-88    1.67    Implement 2-way scroll buttons (use ADJUST)
;;  5-May-88            Don't pass UpCall on even if Cancel selected
;;  5-May-88    1.68    Print 'Press SPACE or click mouse' after text error
;;  6-May-88    1.69    Fix bug: Task_PollIdle was bit 19 (same as Mess_Ack)
;; 13-May-88    1.70    Fix bug: task must be paged in for seticonptrs
;; 18-May-88            Implement Wimp_TransferBlock
;; 20-May-88            Fix bug: RMA leak if task dies while not mapped in
;; 20-May-88            Remove code to claim RMA block in advance
;; 20-May-88            Extend CommandWindow spec so ShellCLI can use it
;; 20-May-88    1.71    Force screen size towards default on mode change
;; 23-May-88    1.72    Fix bug: system icons didn't call seticonptrs
;; 23-May-88    1.73    Allow Sspr1,spr2 in validation string for txt+spr icons
;; 23-May-88            Fix bug: Wimp_TransferBlock mustn't disallow RMA tasks
;; 23-May-88            Change default palette so colour 7 is 0,0,0 RGB
;; 23-May-88            Tweak Wimp_Init so commandwindow state OK if error
;; 23-May-88            Fix bug: move CommandWindow off from CloseDown to Poll
;; 23-May-88    1.74    Add Wimp_ReadSysInfo call to read no. of active tasks
;; 23-May-88            Change Wimp_StartTask so task is initially 'dead'
;; 23-May-88    1.75    Implement button type 11 (select+notify / drag)
;; 23-May-88    1.76    No MODE on singletask exit if commandwindow pending
;; 24-May-88            Fix bug: SlotSize doesn't send message if task dead
;; 24-May-88    1.77    Cope with '*desktop' from old-style tasks
;;                      reset screen on Init/Exit, and set pending on closedown
;; 25-May-88    1.78    Fix bug: change handlers BEFORE mapping slot out
;; 25-May-88    1.79    Fix bug: nulltaskhandle introduced for null events
;; 25-May-88            Change double-click movement limit to 16 OS units
;; 25-May-88            Fix bug: CommandWindow (1) didn't set up keys
;; 25-May-88    1.80    Add Service_WimpCloseDown for ShellCLI etc.
;;  2-Jun-88            Fix bug: send Message_ModeChange before OpenWindowRq's
;;  3-Jun-88    1.81    Fix bug: page in correct task before OpenWindowRq
;;  7-Jun-88            Fix bug: set text window immediately in CommandWindow
;;  7-Jun-88            Use SWI OS_Confirm in Wimp_ReportError
;;                      - removed in Wimp 1.84
;;  7-Jun-88    1.82    R1 bit 3 in Wimp_ReportError ==> don't wait for key
;;  8-Jun-88    1.83    Allow ESC to cancel menu tree (bodged hot-key)
;;  8-Jun-88            Remove SWI OS_Confirm in Wimp_ReportError
;;  8-Jun-88    1.84    Fix bug: sh-f4 in dbox (caused by int_close_window)
;;  9-Jun-88    1.85    Fix bug: FontSetPalette called with wrong parameters
;; 21-Jun-88            Check for invalid pointers on entry to Wimp SWIs
;; 21-Jun-88            Change default palette so colour 14 is 0,0,0 RGB
;; 21-Jun-88            Introduce 2 iconsprites areas (1 RAM, 1 ROM)
;; 21-Jun-88            Change Wimp_BaseOfSprites to reflect this
;; 22-Jun-88            Change Wimp_MergeSprites to Wimp_SpriteOp
;; 22-Jun-88            Use ttr to implement sprite inverting/shading
;; 23-Jun-88            Fix bug: use title width if minx=0 (ignore miny)
;; 24-Jun-88            Fix highlighting of text+sprite icon
;; 24-Jun-88            Keep error box central (don't follow mouse)
;; 24-Jun-88    1.86    Move/resize don't bring to front if SHIFT pressed
;; 27-Jun-88    1.87    Fix bug: toggle should look at shift key also
;; 29-Jun-88            Change colour 11 in default palette to full red
;; 29-Jun-88    1.88    Fix bug: use [oldcallback] to stash previous handler
;; 30-Jun-88            Make right-click in scroll bar do reverse page scroll
;;  5-Jul-88            Shrink screen memory to minimum (ignore default)
;;  5-Jul-88            Implement Wimp_SetFontColours
;;  5-Jul-88    1.88a   Implement the 'F' field in validation strings
;;  6-Jul-88    1.88b   Implement formattable text icons
;;  6-Jul-88            Implement bit 4 in ReportError (omit 'Error from')
;;  6-Jul-88    1.88c   Change 'Error from ADFS' to 'Message from ADFS'
;; 11-Jul-88    1.88d   Change Shift key stuff to ADJ button
;; 13-Jul-88    1.88e   Implement erf_poll bit (used in UpCall handling)
;; 15-Jul-88    1.88f   Call Hourglass_Smash in Wimp_ReportError (not *pointer)
;; 18-Jul-88    1.88g   Fix bug: Wimp to preserve terminator in writeable icons
;; 19-Jul-88    1.88h   Implement backwindow template (not colour 15)
;; 19-Jul-88    1.88i   Fix bug: disallow 'hot keys' in single tasks
;; 19-Jul-88    1.88j   Change: set default mode colours on exit from wimp
;; 19-Jul-88    1.88k   Fix bug: close menus immediately if old-style task
;; 19-Jul-88    1.88l   Fix bug: check CAOPointer up to ApplicationSpaceSize
;; 21-Jul-88    1.88m   Fix bug: Wimp_ReportError with erf_poll set (various)
;; 25-Jul-88    1.88n   Fix bug: Wimp_ProcessKey must page in correct task
;; 25-Jul-88    1.88o   Fix bug: menus kept disappearing after [f1] [RETURN]
;;                               (open backwindow/iconbar at back, not front!)
;; 26-Jul-88    1.88p   Fix bug: set flagword=0 when system task paged in
;; 29-Jul-88            Make *Pointer use Wimp_SpriteOp (SetPointerShape)
;; 29-Jul-88            Don't map colour 15 onto a grey scale
;; 29-Jul-88            Implement ^U in writeable icons
;; 29-Jul-88            Allow R1=0 in Wimp_SetPalette to set default palette
;; 29-Jul-88            Return icons -2 etc. for new-style tasks (-1 for old)
;; 29-Jul-88            Add vertical scroll bar if menu is too high
;; 29-Jul-88            Beep in Wimp_ReportError if wimpflags bit 4 unset
;; 29-Jul-88            Fix bug: remember OK/Cancel colours for later
;; 29-Jul-88    1.88q   Fix bug: open singletasking backwindow at FRONT !!!
;; 29-Jul-88    1.88r   Make toggle icon work properly with SetExtent etc.
;;  1-Aug-88    1.88s   Change Wimp_SpriteOp SetPointerShape to default palette
;;  1-Aug-88    1.88t   Fix bug: wrong memory limit check in Wimp_TransferBlock
;;  2-Aug-88            Change default slot size to 80 pages (640k on a 310)
;;  2-Aug-88    1.89    Fix bug: don't rub out text bg in Sprite+Text if null
;;  3-Aug-88    1.89a   Fix bug: CreateMenu doesn't work if scrollbar needed
;;  3-Aug-88    1.89b   Change default slot size so it's always 640k
;;  8-Aug-88    1.89c   Fix bug: text origin is slightly wrong in MODE 20
;; 10-Aug-88    1.89d   Fix bug: text origin is still wrong in MODE 20!
;; 15-Aug-88            Fix bug: Wimp_ProcessKey gave bad task handle for CR
;; 15-Aug-88    1.89e   Fix bug: function keys ignored ctrl codes
;; 15-Aug-88    1.89f   Fix bug: deleted icons accessed by drawing code
;; 15-Aug-88    1.89g   Store taskhandle in location &FF8 for Stuart
;; 16-Aug-88    1.89h   Check Exec file handle on exit from a task
;; 18-Aug-88    1.89i   Fix bug: Wimp_ReportError in command window was wrong
;; 19-Aug-88    1.89j   Fix bug: acknowledge escape in Exec file stuff
;; 19-Aug-88    1.89k   Fix bug: Wimp breaks MemoryLimit if no free pool
;; 19-Aug-88    1.89l   Wimp_Init: set mode if new task without cf_pending
;; 22-Aug-88    1.89m   Wimp_Init: don't set mode twice for 1st task
;; 24-Aug-88    1.89n   Fix bug: command window left suspended if erf_pollexit
;; 24-Aug-88    1.89o   Fix bug: Wimp breaks MemoryLimit if no free pool
;;  1-Sep-88    1.89p   Remove ":" from UpCall string
;;  8-Sep-88    1.89q   Fix bug: force native ecf's inside Wimp environment
;;  9-Sep-88    1.89r   Fix bug: Wimp_SendMessage returned incorrect R2
;;  9-Sep-88    2.00    Release version!
;; 12-Oct-88    2.01    BUG: pending slot not scanned on screen remapping
;;  8-Nov-88    2.02    BUG: Wimp objects to >= 256 pages, not > 256
;; 19-Dec-88    2.03    BUG: Message block too small not checked for
;;  5-Jan-89    2.04    BUG: Wrong value of CAOPointer read in OS_ChangeDynamic
;;                      - don't store CAOPointer in Service_NewApplication
;;                      - don't overwrite CAOPointer in Wimp_Initialise
;;  5-Jan-89    2.05    BUG: Address exception if 0 pages on startup
;;                   (  Retrospective version for Fox produced
;; 31-Jan-90    =====(  With 'bigmac' true (for > 256 pages)
;;                   (  Changes from: 2.07 / 2.10 / 2.41 / 2.65
;; 12-Jan-89    2.06    BUG: Wimp_ReportError <escape> always returns R1=1
;; 10-Feb-89    2.07    Enable interrupts in Service_MemoryMoved (MOS bug)
;; 28-Mar-89    2.08    Implement 2-way scrolling (drag_scrollboth)
;; 21-Apr-89    2.09    Errors in Wimp_Poll are reported internally
;;                      debugescape option introduced
;; 23-May-89            Remember pointer position over a mode change
;;                      Use separate buffers for errors and starttask
;;                        (Problems if task causes an upcall)
;;                      Report error if window deleted while dragging
;;                      Stop dragging menu / dbox if menus closed
;;                      *Help WimpSlot message altered slightly
;;                      Move dynamic error block up 4 bytes
;;                        (It's overlaid on the error handler's buffer!)
;;                      Ensure that Wimp_CreateMenu can return an error
;;                      Check for errors while creating menu icons
;;              2.10    Delete menu window if error while creating icons
;;              2.10    Correct behaviour of caret / menu selection
;; 25-May-89    2.11    Switch off pointer during 2-D scrolling
;;  9-Jun-89    2.12    Return task handle from Wimp_StartTask
;; 22-Jun-89    2.13    Issue Open_Window_Requests later on a mode change
;; 24-Jul-89    2.14    Issue Open_Window_Requests from back to front
;;                      Also allow for window stack changing (make a copy)
;; 25-Jul-89    2.15    Fix pointer readjustment when drag extent changes
;; 26-Jul-89    2.16    Allow windows to go off bottom-right (if CMOS bit set)
;;                      Implement wf_onscreen for menus
;;                      Implement ws_onscreenonce for toggling and mode change
;;                      Round window extent to pixels in Wimp_SetExtent
;;                      Disallow double-click with different buttons
;;                      Allow iconbar to scroll even if a drag is in progress
;; 27-Jul-89    2.17    Change pointer shape during double-click period
;;                      Cancel double-click as soon as ptr moves away
;;                      Cancel double-click if Wimp_DragBox is called
;; 27-Jul-89    2.18    Allow messages for menu windows to go to menu owner
;;                      Implement Wimp_GetMenuState
;; 28-Jul-89    2.19    Increase drag timeout to 1/2 double-click timeout
;;                      and report drag immediately if pointer moves too far
;; 28-Jul-89    2.20    Implement *Wimp_SetMode (equivalent to the SWI)
;;                      If first char=22, command window is not displayed
;; 31-Jul-89    2.21    Allow iconbar icons to be opened next to each other
;;  1-Aug-89    2.22    Fix bug: handle must be returned from openiconbar
;;  1-Aug-89    2.23    Implement new Wimp_Poll(Idle) bits in R0 which indicate
;;                      that R3 is a pointer to a 'poll word'.
;;  2-Aug-89    2.24    Fix bug: the above didn't work with Wimp_PollIdle
;;  2-Aug-89    2.25    Change name of *Wimp_SetMode command to *WimpMode
;;  3-Aug-89    2.26    Set bit 14 of windowflags on create/setextent
;;  3-Aug-89    2.27    Set bit 14 of windowflags on menu/dbox creation
;;  3-Aug-89    2.28    Implement erf_nobeep bit in Wimp_ReportError
;;  7-Aug-89    2.29    Increase drag radius to 32 OS units
;; 10-Aug-89            Increase double-click radius to 32 OS units
;; 10-Aug-89    2.30    Include file_fea and small_fea in sprite pool
;; 24-Aug-89    2.31    Get ROM sprite area via Wimp$Path
;; 30-Aug-89    2.32    Don't give error in Init if sprites can't be found
;;  7-Sep-89            Make recalcpalette suspend/resume command window
;;  8-Sep-89    2.33    Fix syntax message for *WimpMode <n>
;; 14-Sep-89            Make *IconSprites look for <file>23 if in mono mode
;;                      Pick up DeskFS:$.Sprites or DeskFS:$.Sprites23
;;              2.34    Add Wimp_ReadSysInfo R0=1 => R0=current Wimp mode
;; 14-Sep-89    2.35    Fix bug with OpenWindowRequests going to menu owner
;; 20-Sep-89            Don't issue Message_ModeChange unless mode different
;; 20-Sep-89            Don't scroll iconbar on mode change
;; 20-Sep-89            Make Wimp_ReportError box same as text one re: escape
;; 20-Sep-89            Increase max number of windows to 256
;; 20-Sep-89    2.36    "Bad Wimp mode" for double-pixel modes
;; 21-Sep-89    2.37    Implement FP register saving
;; 21-Sep-89    2.38    Implement flexible window extents
;; 21-Sep-89    2.39    Implement double-width caret plotting (VDU 5 only)
;; 22-Sep-89    2.40    Fix bug: don't re-open backdrop & iconbar if same mode
;;  2-Oct-89            Fix bug: the following calls should accept window -2:
;;                               Wimp_GetWindowState     Wimp_GetWindowInfo
;;                               Wimp_GetWindowOutline   Wimp_ForceRedraw
;;                               Wimp_DragBox            Wimp_WhichIcon
;;                      Make caret single-width again
;;              2.41    Allow > 256 pages (use word array for free pool)
;;  3-Oct-89    2.42    Allow f11 to toggle iconbar between front and back
;;  4-Oct-89    2.43    Fix bug: Wimp_ForceRedraw(-2) did screen not iconbar
;;  6-Oct-89    2.44    Make *WimpMode only set the mode if different
;; 18-Oct-89            Change f11 behaviour to toggle the 'back' bit
;;                      Wimp_GetWindowInfo R1 bit 0 set => don't return icons
;;              2.45    Wimp_LoadTemplate R1 <= 0 => return block sizes
;; 20-Oct-89    2.46    Fix bug: Wimp_LoadTemplate can take -ve R1
;; 20-Oct-89            Make Wimp_SetExtent only set ws_onscreenonce if
;;                      window was entirely on the screen
;;              2.47    Make Wimp_OpenWindow prevent windows getting bigger
;;                      than the screen size even if they're not being
;;                      forced onto the screen.
;; 20-Oct-89    2.48    Call recalcpalette before int_allbutmode on mode change
;; 24-Oct-89            Ignore clicks on greyed-out menu items
;; 25-Oct-89            Return Message_MenusDeleted if menus deleted
;; 25-Oct-89    2.49    Return mouse clicks via messages if queue non-empty
;; 25-Oct-89            Use HiResMono bit to decide whether to use Sprites23
;; 25-Oct-89    2.50    Wimp_OpenWindow should keep window on screen if was closed
;; 26-Oct-89    2.51    Make menu disappear if SELECT clicked on grey item
;; 27-Oct-89            Allow interactive help to 'see' greyed-out menu items
;; 27-Oct-89    2.52    Implement mif_traverse (can see submenus of grey items)
;; 27-Oct-89            Issue Service_WimpPalette on Wimp_SetPalette
;; 27-Oct-89    2.53    Return R2 = sender's task handle from Wimp_Poll(Idle)
;;                      (Only if task knows about Wimp 2.53)
;; 30-Oct-89    2.54    Call int_sendmessage_fromwimp to give taskhandle 0
;; 31-Oct-89    2.55    Fix bug: *Iconsprites in mode 23 used wrong R2
;;  3-Nov-89    2.56    Issue Message_MenusDeleted when escape kills menus
;;  9-Nov-89    2.57    *IconSprites tries <filename>20 if <= 2 OS units per ypix
;; 10-Nov-89            *IconSprites tries <filename><x><y><bpp>, then <filename>
;;                      It also uses the values cached in getromsprites
;;              2.58    Wimp_ReadSysInfo (2) returns ptr to xeig,yeig,log2bpp
;; 15-Nov-89    2.59    Change *WimpTask so it works from a dead task
;; 15-Nov-89    2.60    Change IconSprites to use <x><y> or "23"
;; 16-Nov-89    2.61    Implement Wimp$State ("desktop" or "commands")
;; 17-Nov-89            Make Wimp_ReadSysInfo (3) return 0 or 1
;;              2.62    f11 looks at whether window is covered, and sets wf_backwindow
;; 20-Nov-89            Still send Message_ModeChange even if same mode
;;              2.63    But don't set ws_onscreenonce unless size smaller in x or y
;; 30-Nov-89            Fix FP register saving, and set status=&7000 if not saved
;;                      Fix scrolled menu dotted line redrawing
;;                      Don't send iconbar to back on mode change
;;                      Use OS_CheckModeValid when checking for HiResMono modes
;;              2.64    Clear bottom bits of palette entries in Wimp_ReadPalette
;;  1-Dec-89            Don't send Message_SlotSize if slot is same size
;;                      Report memory full errors in Wimp_SlotSize correctly
;;                      Make OS_ChangeDynamicArea and findpages work with 16Mb
;;                      Allow pointer to go off bottom-right in size dragging
;;                      Fix bug: don't zero bottom bytes in Wimp_ReadPalette
;;              2.65    Ensure that pointerwindow coords are signed 16-bit
;;  6-Dec-89    2.66    Fix bug: Wimp_SlotSize corrupted R4 on exit!
;;  7-Dec-89            Fix bug: Wimp_LoadTemplate didn't count indirected data properly
;;                      Fix bug: turn double-click ptr off if pending window deleted
;;              2.67    Fix bug: allow validation = 1 and size <= 0 in templates
;;  8-Dec-89    2.68    Add "-next" parameter to *WimpSlot command
;;  8-Dec-89    2.69    Change default Wimp palette so it works better in mode 15
;; 31-Jan-90            Introduced 'bigmac' switch for Fox Wimp (additions to 2.05)
;; 19-Feb-90    2.70    Included resource files inside module, using ResourceFS
;; 23-Feb-90            Implement *WimpWriteDir for changing to Hebrew mode
;;                      Menus with title starting "\" are reversed
;;              2.71    Wimp_ReadSysInfo (4) returns current write direction
;; 23-Feb-90    2.72    Fix bug: didn't initialise ROM sprites if loaded after ResourceFS
;; 26-Feb-90    2.73    Allow Wimp_CreateIcon with R1 = -5,-6,-7,-8
;; 28-Feb-90    2.74    Fix bug: iconbar extent should be pixel-aligned
;;  9-Mar-90    2.75    Fix bug: return click from menu icon if clicked as the mouse enters
;; 13-Mar-90    2.76    Icons stored separately from windows. This allows window structs to stay still.
;;                      Change sequence of LNKs to GETs from Sources.Wimp
;;                      Change references to headers to Hdr:, not &.Hdr.
;;                      Pass reason code messages <= CloseRequest through the message system
;;                        under task ID 'pmiW' ("Wimp"), this enables mode change to send open messages for
;;                        all windows.
;;                      Send messages for all windows being opened after a mode change, and
;;                        stop using the stack to hold the window stacking order for this
;;                        operation.
;;                      Implement infinite windows.
;;                      Backwindow bit slightly changed in meaning: now, the frontmost back window
;;                        determins where windows opened behind window -2 get opened; if a specific
;;                        window handle is given, even if that window is behind a back window, then the
;;                        opened window will open behind the window specified.
;; 26-Mar-90    2.77    Handle rectangle area full redraw screen better:
;;                        braindead_panic_redraw indicates the state of the rect area full problem:
;;                              2 - not full, everything's ok. If the rect area becomes full this upgrades
;;                                      to a 2.
;;                              3 - has become full once, we are currently in the redraw whole
;;                                      screen intelligently scheme. If the rectangle area becomes
;;                                      full in this state this upgrades to a 3.
;;                              0 - has become full once and all rectangle operations should be ignored.
;;                                      If redraw notices this on entry to redrawing this will downgrade
;;                                      to a 1 with the whole screen as the invalid rectangle.
;;                              1 - has become full whilst doing an intelligent whole screen redraw due to
;;                                      a rectangle area full. This means its time to do a
;;                                      BRAINDEAD_PANIC_REDRAW. Redraw noticing this will commence doing
;;                                      a brain dead redraw sequence (redraw all of all the windows from
;;                                      the back of the stack to the front).
;;                              <window handle> - braindead_panic_redraw is in progress. This handle is the
;;                                      handle of the next window to be redrawn braindead fashion. Once
;;                                      the stack has been redrawn this flag drops to 0 again.
;;                        So, the sequence if the stack is only slightly full (eg a task with a huge
;;                        number of windows is closing down, overflowing the rectangle area as all the windows
;;                        are closed, but eventually leaving a less complex rectangular situation) is:
;;                              2 - then rect area becomes full
;;                              0 - then more rect operations do nothing as the windows are closed
;;                              0 - then the redraw comes along and notices this, downgrading to a
;;                              3 - intelligent redraw happens which has no problems due to the much
;;                                      reduced window stack.
;;                              3 - intelligent redraw finishes and the system settles back to a
;;                              2 - no problem.
;;                        The sequence if there are just too many windows to handle is:
;;                              2 - rect area becomes full
;;                              0 - then more rect operations do nothing, until
;;                              0 - redraw comes around and downgrades to a
;;                              3 - and starts doing an intelligent redraw, after a while of redrawing
;;                              3 - the rect area becomes full (again) causing an upgrade to a
;;                              1 - which the redraw sequence picks up, and skips out to do a braindead
;;                                      redraw sequence.
;;                              1 - braindead redraw sequence starts (clears background then)
;;                              <window handle> - redraw this window braindead fashion, then run out of windows
;;                              2 - no more windows, back to 'normal'.
;;                        Notice in states 0 and 1 rectangle operations should be curtailed, but
;;                          in states 2 and above (unsigned) rectangle area operations are ok (above 3
;;                          the operations should have been vetted by the panic redraw handling to be safe).
;; 13-Jul-90    2.78    Fix bug: address exception when clicking on greyed-out menu item
;; 02-Aug-90    2.79    Iconize messages implemented.
;; 04-Aug-90    2.80    Fix bug, address exception when task died while pointer in one of its windows.
;; 14-Aug-90    2.81    Changed number of tasks to 128.
;; 03-Sep-90    2.82    F11 action (Toggle iconbar) moved to F12.
;; 20-Sep-90    2.83    Fixed bug, drag user sprite called move address first
;; 20-Sep-90            now calls plot first.
;; 25-Sep-90    2.84    Centre error box on screen.
;;                      Fixed bug in 3d writable icons, colour now forced only if icon has a border.
;;                      Fixed bug in 3d icons, wrong colours in 8bpp modes.
;;                      Added r3-> list of messages expected if task knows about version 284 or later.
;;                      Moved task priority and message list code to be conditional on Version >= 284
;;                      and not on Swapping.
;;                      Shift-Full_Size toggle to max size that doesn't hide icon bar.
;; 30-Nov-90    2.85    Added pointer shape changes (P command in validation string).
;;                      Added border types for icons (B command in validation string).
;;                      Added SWI Wimp_RegisterFilter for filter manager.
;; 02-Jan-91    2.86    Read timeouts and distances from CMOS RAM.
;;                      Added auto submenu opening.
;; 05-Mar-91    2.87    Fixed bug in messages list.
;;                      Uses OS_ReadSysInfo to read configured mode.
;; 21-Mar-91    2.88    Fixed bug: Now Uses OS_ReadSysInfo to read configured
;;                      mode in both places where it is read.
;; 30-Mar-91    2.89    Added sysflags_nobounds to enable all windows be opened off screen
;;                      in all directions.
;;                *     Fixed bug in NewLook stuff that changed graphics clip window
;;                      while dragging without instant effects enabled.
;;                *     Added UserBars flag to enable the use of sprites for all the window
;;                      tools including the scroll bars.
;;                *     Removed *Configure wimpmode.
;;                *     Changed template loading to use OS_File, and fall back
;;                      to OS_GBPB if the OS_File fails.
;;                *     Moved toggle icon bar to Shift+F12
;; 24-Apr-91    2.90    Cache UserBars sprites on init and mode changes.
;;                *     Divided userBars title sprite into two.
;;                *     Read configured mode when first task starts.
;;                *     Fixed a number of positioning bugs in UserBars stuff
;;                *     Added slowdown code for portable.
;; 06-May-91    2.91    Changed delay configuration units to 1/10 sec.
;;                *     Added WimpMenuDragDelay
;;                *     Fixed bug: horizontal scroll bar vanished in 8bpp modes when
;;                      y0 was 0 (R7 was set to 0 on entry to getspriteinfo).
;; 28-May-91    2.92    Added K command in validation string
;;                *     Wimp now looks sprites up in Wimp pool if not found in window's
;;  1-Jun-91    2.93    Fixed bug, page in task to check for mouse events enabled.
;;                *     Fixed bug, caret data returned for correct icon if KNA
;;                *     Fixed bug, don't page in input focus task if no key pressed
;;                *     Fixed bug, KR,KT now move to end of data in new icon.
;;                *     Fixed bug, Auto menu no longer opens greyed out submenus.
;;                *     Changed sprites, removed pointer sprites.
;; 14-Jun-91    2.94    Bug fixes
;;              2.95    Fixed bug, Wimp_ReportError stiffed machine if R1=0 on entry and in text mode.
;;                *     Fixed bug, !Madness made icon bar move.
;;                *     Added SWI Wimp_AddMessages
;;                *     Wimp_Initialise now only reports an error if passed in version is <200 or > 300
;;                      if 200 < version < 300 then  200 is used as the version number.
;;                *     Error boxes now only respond to <CR> and <Esc>.
;; 07-Aug-91    2.96    Fixed bug, crashed on soft key expansion
;;                *     Fixed bug, check that window for opening behind is open.
;; 28-Aug-91    2.97    Added redraw and block copy filters.
;;                *     Fixed ARM IIas bug.
;;                *     Fixed submenu opening in wrong place bug
;;              2.98    Made Wimp respond to Service_ValidateAddress
;;              2.99    * DOES NOT EXIST *
;; 17-Sep-91    3.00    Release version !!! (For RISC OS 3.00)
;; --------------------------------------------------------------------------------------
;; 25-Nov-91            Wimp now looks up messages in MessageTrans in normal way, defaults are not held in the code module.
;; 25-Nov-91            Bug fix: Call to filters used ADR LR, now uses MOV LR,PC
;; 25-Nov-91    3.01    Implemented portable speed control.  Now only calls Protable_Speed if Portable module is present.
;; --------------------------------------------------------------------------------------
;; 26-Nov-91            Modified to use ColourTrans for colour mapping
;; 29-Nov-91            Fix bug: WimpSlot now accepts 6 parameters ie: "-min <n>k -max <n>k -next <n>k"
;; 30-Nov-91            Uses ColourTrans for setting GCOLs.
;; 30-Nov-91            Wimp_ReadPixTrans now uses dynamic workspace.
;; 30-Nov-91            Check dither CMOS on mode change and set a suitable workspace location.
;;  3-Dec-91            Implement Wimp_SetColourMapping.
;;  5-Dec-91            Optimised for 1:1 mapping on colours - sets needsfactors.
;;  5-Dec-91            Inversion and greying of sprites re-introduced.
;;  5-Dec-91            Bug fix: When looking for a sprite tries the wimp pool if all fails.
;;  5-Dec-91            Bug fix: User gadgets now plot using correct mappings - also optimised for space.
;;  5-Dec-91            Bug fix: Wimp_ReadPalette reads the mapping palette if applied.
;;  5-Dec-91            Bug fix: Remapping colours works correctly.
;;  6-Dec-91            Bug fix: Wimp_ReadPalette now returns the pointer colours if remapping applied.
;;  6-Dec-91            Bug fix: Screen redraw if Log2BPP >=8 and remapping is *not* applied on setting the palette.
;;  6-Dec-91            Consistent and improved greying and inversion of sprites.
;;  9-Dec-91            New caret plotting introduced.
;; 11-Dec-91    3.02    Bug fix: Caret inversion colours corrected.
;; 30-Dec-91            Bug fix: Die entry when reporting Wimp cannot die error message.
;; 10-Jan-92    3.03    In monochrome modes always dither Wimp colours 0-7.
;; 10-Jan-92            Wimp_ReadPalette works properly; R2 ="TRUE" means return full 24bit values.
;; 10-Jan-92            Wimp_SetPalette works properly; R2 ="TRUE" means user specifing full 24bit values.
;; 10-Jan-92            Bug fix: recalcpalette no longer forces redraw of the screen unless really needed.
;; 10-Jan-92            Bug fix: Wimp_ReadPalette returns GCOL in bottom eight bits.
;; 14-Jan-92            Experiment with new inversion code and ColourTrans functions.
;; 14-Jan-92            Recoded the despatch of Wimp_ReadSysInfo reason codes.
;; 15-Jan-92    3.04    Bug fix: When setting palette preserve supremacy bits.
;; 15-Jan-92            Bug fix: Screen update in 8BPP modes when palette changed.
;; 18-Jan-92            Dot dash line rotation speed now based on timer, rather than internal counter.
;; 23-Jan-92    3.05    Tweeked the rotation speed of the line, tad faster.
;;  7-Feb-92            Service_WimpSpritesMoved added - R2,R3 -> ROM, RAM sprite pools.
;;  7-Feb-92            Added sprite name caching routines.
;;  7-Feb-92            Intergrated the use of sprite name cache.
;;  7-Feb-92            Improved sorting performed on the sprite list.
;;  7-Feb-92            Removed lots of conditional assembly from Wimp01.
;;  8-Feb-92            Removed more conditional assembly, sorted out internationalised code and service trapping.
;; 12-Feb-92            Bug fix: Message token lookup for media search boxes.
;; 12-Feb-92       **   Bug fix: Wimp_ReportError getting the title bar wrong.
;; 12-Feb-92            Now uses OS_FindMemMapEntries rather than its own *SLOW* implementation.
;; 12-Feb-92            Wimp_RemoveMessages added.
;; 12-Feb-92            Improved seaching of messages list - now stored on a per-task basis.
;; 12-Feb-92            Bug fix: duplicate removal on sprite list sort is biased towards RAM pool.
;; 13-Feb-92            More conditional code removed (Wimp06).
;; 13-Feb-92            Icon borders tidyied and added back in.
;; 14-Feb-92            Template loading catches resources: objects.
;; 15-Feb-92            Bug fix: caching sprites gets correct prefix.
;; 16-Feb-92            Indirected menu titles implemented for long application titles.
;; 16-Feb-92            Bug fix: indirected title bars and wimp created sub-menus.
;; 16-Feb-92            Bug fix: Rogers palette problems - not converted properly.
;; 18-Feb-92            Changed the reseting of filters to a default state, and issuing of Service_RegisterFilters
;; 18-Feb-92            Re-ordered filter despatch workspace; now called using LDMIA Rx,{WP,PC} - coded to macro.
;; 18-Feb-92            Wimp_ReadSysInfo (5) get current task + version of task.
;; 19-Feb-92            Bug fix: all filters passed R2 contain task handle.
;; 23-Feb-92            Only plot the icon borders if task specified Wimp version >= 306, solves clash of validation strings.
;; 23-Feb-92            Added *ToolSprites command to allow loading of sprite borders for windows.
;; 24-Feb-92            Caching of the tool sprites information added.
;; 24-Feb-92            Bug fix: border sprites not seen by Wimp_PlotIcon / Wimp_SpriteOp - saves confusion.
;; 25-Feb-92            Finished new tools sprites routines.
;; 25-Feb-92            Changed syntax of ToolSprites to allow no parameters - meaning default set from WindowManger:Tools.
;; 25-Feb-92            Bug fix: excessive recaching of sprite border pointers - only does once on a mode change.
;; 25-Feb-92            Bug fix: does not reprogram the VDU 5 glyphs if the tool sprites are present.
;; 26-Feb-92       **   Bug fix: slot size genertes the correct error if not enough memory - not gobbldy gook!
;; 26-Feb-92            Bug fix: source clipping works properly on window gadgets.
;; 26-Feb-92            Further optimisation of dofunkytitle, dofunkyhscroll and dofunkyvscroll.
;; 26-Feb-92            Now keeps SpriteOp paramaters cached to save recalculating them.
;; 26-Feb-92            Some more conditional code removed.
;; 26-Feb-92            Bug fix: pre-scroll offset for scroll bars adjusted by borders properly.
;; 26-Feb-92    3.06    If not sprite tools loaded then falls back to VDU 5 style glyphs, including reprogramming welsh doofers.
;; 27-Feb-92    3.07    Fix bug in Wimp10 preventing error boxes working on dead tasks.
;; 11-Mar-92    3.08    LRust - fix help message for WimpMenuDragDelay - fixes G-RO-8313
;; 12-Mar-92            LRust - messages flag is initialised immediately after claiming ws to ensure
;;                        if errors are looked up during init (eg in ValidateMode) no address exceptions
;;                        occur (e.g. if invalid configured screen mode). Fixes RP-0725 and RP-1679
;; 13-Mar-92            LRust - Menu tick and arrow revert to sprites.
;;                       * Tools and sprites are always included, messages and templates
;;                         are included if standalone flag set true.
;; 16-Mar-92            LRust - Mode 23 toolsprites are correctly cached, fixes window border
;;                         redraw errors in mode 23, fixes RP-1691
;; 19-Mar-92     3.09   LRust - Redraw of pressed gadgets fixed to not leave in pressed state
;;                       * help text for WimpDragDelay etc. tidied.
;;                       * Iconsprites now no longer merges the window border tools.
;;                         This speeds up *iconsprites and prevents address exceptions
;;                         caused by cached toolsprites having moved.
;;                       * Wimp_SetCaretPosition now pages in task losing caret if icon
;;                         has indirected data.
;; 24-Mar-92    3.10    LRust - Fixed caret positioning in writable icons by ensuring that
;;                         drawicon_system in Wimp04 adjusts for borders before calling
;;                         findtextorigin - thus text is correctly aligned in bordered icons.
;;                       * Menu titles can be indirected using bit8 of the first menu item
;; 25-Mar-92            LRust - KA validation string now causes caret to move to the same character
;;                         position within the new icon when up or down arrow pressed.
;;                       * Fixed bug RP-2025, adjust drag scroll bars without instant vertical effects
;;                         erroneously called a user drag routine, and went BANG!!
;; 26-Mar-92            LRust - Fix RP-1809, Wimp_ReportError now forces VDU output back to the
;;                         screen before drawing the error box, and restores re-direction and
;;                         other states on exit
;;                       * Fixed RP-1913, Wimp_Initialise now accepts any control character to
;;                         terminate the task descriptor string.  Subr Count0 fixed to do this.
;;                      LRust - Fix RP-1537.  *WimpPalette now checks that there are exactly 16 palette
;;                          entries in the file, thus avoiding problems with the 256 colour variety
;; 30-Mar-92            LRust - KA validation string cause up/down arrow to move to end of new field,
;;                         fixes G-RO-7130, RP-1168
;; 31-Mar-92            LRust - Sprite highlighting changed again! fixes RR-1674 and Rp-1402
;;                        * Sprite graying changed again! fixes RP-2094
;;                        * Initptrs now preserves R0, preventing R0 from being corrupted on Service_Reset
;; 01-Apr-92            LRust - Fix RP-2148 and RP-2150 - F command in validation specifying font colours
;;                          now accepts lowercase hex colour numbers.
;;                        * Fix RP-2153 - Mode change now uses default colour mappings for the mode to ensure
;;                          the physical palette isn't changed by use of Wimp_SetColourMapping to alter
;;                          logical colour mapping.  In addition Wimp_SetColourMapping also forces
;;                          re-caching of tool sprites to ensure the cached palette is correct.
;; 02-Apr-92            LRust - Fix die entry if tasks are active to restore R12 after (and not before!)
;;                          translating the CantKill error.
;; 03-Apr-92            LRust - Add constants to define validation strings.
;;                        * Service_InvalidateCache invalidates toolsprite cache.
;;                        * Add reason code 7 to ReadSysInfo to return Wimp version
;;                        * The wimps's templates are now loaded by first finding the buffer size
;;                          required, allocating the buffer and then loading the template
;;                        * Fix RP-2030, Wimp_ProcessKey correctly inserts keystrokes into writeable
;;                          icons even if the window is not topmost.
;;                        * Icon border validation string correctly parsed for highlight colour
;; 07-Apr-92    3.11    LRust - Dofunkyvscroll and hscroll fixed to only plot icons if clipping rectangle
;;                          is non null, pressed hscroll drawn correctly.  Fixes RP-1766 and other 3d complaints
;;                        * Service_InvalidateCache disposes of tool_list only, redrawing window with
;;                          empty tool_list calls maketoollist to re-cache tool info.
;;                        * IconSprites now correctly checks for duplicates at end of sorted list
;;                           fixes RP-2127
;;                        * Wimp_DeleteIcon now correctly deletes a writable icon with the caret,
;;                           fixing RP-0803
;;                        * Disabled editable icons with border command validation don't have black border
;; 09-Apr-92    3.12    LRust - ExitPoll only calls post filter if event in R0 is valid (ie not when
;;                          R0 is setup for Wimp_StartTask.
;;                        * ExitPoll call to portable module for non null events optimised.
;; 13-Apr-92            LRust - Recoded scanpollwords to use a packed list of pollword tasks to improve
;;                           search time.  Fixes G-RO-7574
;;                        * Submenus now displayed immediately to right of arrow (left in hebrew), not
;;                           to right of window, in case title wider than item.
;; 15-Apr-92            LRust - Fixed template loading to correctly preserve file handle if insufficient
;;                           RMA to cache the file.  Fixes RO-8608 (Acorn DTP not starting on 1 Mb machine).
;;                        * Wimp_ReportError correctly returns cancel if escape pressed with highlight on ok
;; 22-Apr-92            RMokady - Take away input focus from windows open behind the backdrop (-3)
;;
;; 23-Apr-92    3.13    LRust - Fixed scrollbar redraw problem when off screen and moved in negative direction.
;;                      RMokady - Fixed problem with caret size not taking into accound wide borders.
;;                        * Added Squash sprite to ROM sprite file
;; 24-Apr-92    3.14    LRust - Fixed CopyFilter to preserve R2, debugged CallAFilter macro
;; 29 Apr-92    3.16    LRust - fixed address exception during mode change with little RMA
;;                        * VDU 5 glyphs correctly used for undefined toolsprites
;; ---------------------------------- RISC OS 3.10 release version ----------------------------------
;; 17-Jun-92            Bug fix: deleting window with active icon in it - no longer goes bang!
;; 17-Jun-92            Stripped more conditional code, leaving just the poll word speeds ups by Lawrence
;; 17-Jun-92            Mouse polling reduced to 100hz - ticker sets internal flag and then we read next time
;; 17-Jun-92            Scroll bars now have new blip icons, plotted centrally on the bar
;; 19-Jun-92            Bug fix: Shift toggle no longer thinks the window *ISN'T FULLED*
;; 22-Jun-92            Wimp_ReadPalette with bpp >= 16 does not return colour numbers in bottom bytes
;; 26-Jun-92            Optimising of the pixel translation table no longer performed if > 256 entries (needed for 16bpp)
;;  1-Jul-92            FindNext and FindPrev for editable fields now looks at ESG group within icons
;;  6-Aug-92            Bug fix: blip handling min size of window limited by these sprites
;;  6-Aug-92            Bug fix: Illegal character sequence in Font_Paint string no longer generated with fancy font fields
;;  6-Aug-92            Some optimisations, TickerV released correctly on deallocpointers!
;;  7-Aug-92            Started support for Wimp$Font and Wimp$FontSize
;; 10-Aug-92            Bug fix: Fancy font handling now works using Font_Paint rather than old style VDU calls
;; 10-Aug-92            Bug fix: Rubout on fancy fonted icons works again properly
;; 12-Sep-92            Bug fix: Fancy font icons which D in validation string now translate properly
;; 21-Sep-92            Ensure it flushes ColourTranz (sic) cache when palette reprogrammed!
;; 21-Oct-92            Improved some more of the caret handling for fancy font Wimp.
;;
;; 19-Mar-93    3.20    Following enhancements and bug-fixes by Neil Kelleher
;;
;;                      Caret position in dialogs with passwords
;;                      now correct. Base of sprites no longer missing (though still
;;                      a problem in some sizes of text). Can use *Set as well as
;;                      *SetEval to alter text size and width. Empty-string L40
;;                      icons no longer cause Data Abort.
;;                      Auto Menu width ammended as follows: If menu has no writeable
;;                      entries then automatically determine the width, otherwise use
;;                      given menu width as a minimum.
;;                      Fixed bug involving proportional system font being written on
;;                      top of itself
;;                      Fixed bug reported by ddv- if wimp$font is unset then selecting
;;                      an icon knocks off the top line(s) of pixels. Caret moving
;;                      after clicking or typing first character fixed.
;;                      Improved background filling for inverted and sprite+text icons.
;;                      Support Wimp_ReadSysInfo (Reason 8) returning system font
;;                      handle in R0 and symbol font handle in R1. Fixed some validation
;;                      string problems affecting stability.
;;                      Random character problem fixed.
;;                      Unfilled Text icons drawn with correct background- now uses
;;                      correct antialiasing colours.
;;                      Icons with Border validation (eg. R6,14) go correct colour when
;;                      pressed.
;;                      'Kar' bug fixed.
;;                      Wimp now sends message when system font changes.
;;                      Added new SWI, Wimp_GetIconInfo. Creating icons on icon bar, automatically
;;                      widen if text (in current system font) doesn't fit- NOTE, if fontwidth
;;                      changes during desktop use, it is not updated.
;;                      Filer templates removed from wimp RM, WIMPSymbol font built in.
;;                      Implemented prototype features for tiling window backdrops and slab in/out
;;                      of border 1 sprite icons.
;;
;; 21-Mar-93    3.21    Implemented new error system, service calls etc.
;; 15-Jul-93    3.22    Added Medusa memory management support. Fixed various bugs.
;;                      Improved outline system font mechanism. See spec 0384,405/FS.
;; 20-Aug-93    3.23    Added SWI's TextOp (replacing GetIconInfo) ResizeIcon, Extend and
;;                      SetWatchdogState. Added CMOS support for Desktop font. Return and
;;                      escape usable on Custom button dialog boxes. various bug fixes.
;; 27-Aug-93    3.24    Added CMOS control for desktop tiling.
;;-------------------------------------Medusa A Audit version------------------------------
;; 03-Sep-93    3.25    Added different tile depth support. rearranged sources.
;;                      auto menu width now takes sprites into account
;; 17-Sep-93    3.27    altered window furniture code - should be more efficient.
;;                      made DA sprite area on medusa more efficient
;;                      can *WimpMode outside of desktop. fixed a few bugs incl. grey modes
;; 30-Sep-93    3.28    WrCh vector now released on Service_ModeChange - catches 'single tasking'
;;                      apps that change screen mode with OS_ScreenMode rather than VDU 22.
;; 30-Sep-93    3.29    updated to cope with increased sprite op reason code.
;; 03-Oct-93    3.30    updated !WIMPSymbol.
;; 06-Oct-93    3.31    tweaked darwin. reorganised sources - can now build with outlinefont off.
;;                      speeded up mode changes. fixed some selected icon problems.
;; 08-Oct-93    3.32    On Medusa memory is returned when exiting desktop.
;;                      workaround for toolsprites code causing lots of 'can't find sprite'
;; 11-Oct-93    3.33    now uses look up table for program errors. few memory fixes.
;;                      caret is red on 16/32 bit modes.
;; 19-Oct-93    3.34    yet more memory fixes. error block now copied so message trans
;;                      overwritting buffers is ok.
;; 03-Nov-93    3.36    and some more memory fixes! fixed line across the screen from an error
;;                      box bug. increased minimum scrollbar height and fixed cannot scroll to
;;                      end bug.
;; 18-Nov-93    3.37    memory fixes and MED-01061 00973 01097 00297 01103
;; 01-Dec-93    3.38    fixed MED-00967/8 00974 MED-00966 MED-01342 01346 01431
;;                      altered icon selection (faster, sprites slightly different colours)
;;                      ALT-BREAK now used for watchdog.
;; 09-Dec-93    3.39    fixed MED-01406 00776 01228 01588 00414
;; 12-Jan-94    3.40    Stopped acknowledging messages from deleting events : fixes MED-00003 and
;;                      MED-00985. fixed MED-00943, better handling for iconbar icons with variable
;;                      text. fixed MED-00946 01364 01418 01711 01818 01894 MED-02090,1,2122,2146,2202
;;                      fixed MED-02095. recoded tiling.
;; 20-Jan-94    3.41    fixed MED-00240 00563 02050 01910. Tweaked memory management and tiling.
;; 21-Jan-94    3.42    Improved font manager death recovery. fixed (MED-00114) toolsprite probs.
;;                      Wimp_ClaimFreeMemory works on machines with more than 28 meg.
;;                      tweaked error box templates
;; 31-Jan-94    3.44    W_CFM now returns free pool EEK!!!. fixed MED-01852. fixed MED-02443
;;                      fixed MED-02497, fixed MED-01910
;; 03-Feb-94    3.45    improved FM death recovery (now loses fonts so that useage should go down
;;                      to zero). custom buttons get correct border if they are a default (ie. no ok
;;                      or cancel). fixed load template giving spurious errors (affected Magpie and
;;                      Junior Pinpoint). fixed MED-02285. fixed MED-02269
;; 08-Feb-94    3.46    fixed MED-01796. improved Watchdog to cope with special circumstances such
;;                      as a running Print Job or output switched to sprite.
;;                      improved font preservation (when to do it/ when not to). fixed menu delay offset bug.
;; 09-Feb-94    3.47    Thought about font preservation and removed it for now.
;; 11-Feb-94    3.48    Fixed MED-02301, substantially changed unfilled text only icons. Fixed MED-02598
;;                      Fixed bug that could cause program errors to go wrong themselves. fixed tiling bug -
;;                      only occurred when a window had a custom sprite. put in (different) font
;;                      preservation checking. Added 'vertical justification' bit to TestOp, Wimp_RenderText
;; 16-Feb-94    3.49    Fixed W_CFM (asking for lots of memory didn't fail). Added extra FM abuse security
;;                      (eg. MED-00669)
;; 17-Feb-94    3.50    changed Sprite Op's 'can't do that in this depth' error to User one.
;;                      Yeeeee Haaaaaa!!!!! we're here!!!
;;
;; --------------------------------------------------------------------------------------------------
;; ---------------------------------- RISC OS 3.50 release version ----------------------------------
;; --------------------------------------------------------------------------------------------------
;;
;; 21-Apr-94    3.51    (RM) added power saving code for Stork
;; 15-Sep-95	3.71    Remove mode check from module initialisation to enable soft loadable modes.
;;
;;----------------------------------------------------------------------------
;; 29th Apr 97  3.89    (JRC) Modify UpCall handler; restore font colours before calling Service_WimpReportError at end
;;                      of SWI Wimp_ReportError.
;;----------------------------------------------------------------------------
;; 15th Jul 98  3.95    (SMC) Made modifications to make NC's work turn to only use IconHigh when not using
;;                      a mouse and to turn the pointer on and off correctly.
;; 25th Jul 98  3.96    (SMC) Now uses new flag, PreservePointerOnError, to turn on/off the preservation
;;                      of the mouse pointer state over errors. This depends on BuildForNC also being true.
