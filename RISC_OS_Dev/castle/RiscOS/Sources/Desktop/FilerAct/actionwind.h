/* This source code in this file is licensed to You by Castle Technology
 * Limited ("Castle") and its licensors on contractual terms and conditions
 * ("Licence") which entitle you freely to modify and/or to distribute this
 * source code subject to Your compliance with the terms of the Licence.
 *
 * This source code has been made available to You without any warranties
 * whatsoever. Consequently, Your use, modification and distribution of this
 * source code is entirely at Your own risk and neither Castle, its licensors
 * nor any other person who has contributed to this source code shall be
 * liable to You for any loss or damage which You may suffer as a result of
 * Your use, modification or distribution of this source code.
 *
 * Full details of Your rights and obligations are set out in the Licence.
 * You should have received a copy of the Licence with this source code file.
 * If You have not received a copy, the text of the Licence is available
 * online at www.castle-technology.co.uk/riscosbaselicence.htm
 */
/*
        Declare action_environment as being file global in scope
*/
struct  action_environment;

typedef enum
{
        Action_Copying = 0,
        Action_Moving = 1,
        Action_Deleting = 2,
        Action_Setting_Access = 3,
        Action_Setting_Type = 4,
        Action_Counting = 5,
        Action_CopyMoving = 6,
        Action_CopyLocal = 7,
        Action_Stamping = 8,
        Action_Finding = 9
}       actions_possible;

typedef enum
{
        Abort_Operation,
        Next_File,
        Test_Add_To_Read_List,
        Add_To_Read_List,
        Check_Full_Reading,
        Check_Empty_Writing,
        Attempt_1st_Rename,
        Attempt_2nd_Rename,
        Convert_To_CopyMove,
        Convert_To_CopyMove_After_Unlock,
        Attempt_Delete,
        Attempt_Delete_Dir_For_CopyMove,
        Attempt_Set_Access,
        Attempt_Set_Type,
        Attempt_Unlock,
        Attempt_Relock,
        Attempt_Stamp
}       next_action_state;

typedef void (*button_function)( struct action_environment * );

typedef struct
{
        int             requires_interaction:1;
        button_function abort_action;
        button_function no_skip_action;
        button_function yes_retry_action;
        button_function misc_action;
        button_function skip_action;
        char            *button_helps[ 5 ];
}       button_actions;

typedef struct
{
        char *abort_text;
        char *no_skip_text;
        char *yes_retry_text;
        char *misc_text;
        char *skip_text;
}       button_texts;

typedef struct
{
        button_actions actions;
        button_texts   texts;
}       button_set;

typedef struct action_environment
{
    /* Current position in list of files in */
    search_handle           test_search;

    /* wimplib handle onto the dialogue box */
    dbox                    status_box;

    /* wimp handle of the window */
    int                     window_handle;

    /* handle onto menu */
    menu                    option_menu;

    /* information regarding showing/hiding box in a delayed fashion */
    clock_t                 time_to_boxchange;
    int                     boxchange_direction;

    /* numeric quantities for progress lines */
    uint64_t                top_progress;
    uint64_t                bottom_progress;
    #ifdef USE_PROGRESS_BAR
    uint32_t                progress;
    #endif

    /* current overall operation (copying/counting/deleting etc) */
    actions_possible        operation;

    /* next thing to try: next file; read some; set type of file etc */
    next_action_state       action;

    /* new parameters for files (only used when relevant) */
    int                     new_access;
    int                     new_type;

    /* Things to happen when user presses a button */
    button_actions          button_actions;

    /* text on top line of info box */
    char                    *current_info;
    char                    *current_info_token;

    /* used when counting finishes */
    char                    *selection_summary;

    /* infomation for copying files */
    char                    *destination_name;
    int                     source_directory_name_length;

    /* Record of locked files not deleted */
    uint32_t                locked_not_deleted;

    /* Mask to use when setting access on directories for NetFS (KLUDGE) */
    uint32_t                directory_access_setting_mask;

    /* these indicate which switches apply */
    int                     verbose:1;
    int                     confirm:1;
    int                     force:1;
    int                     access:1;
    int                     looknewer:1;
    int                     faster:1;
    int                     faster_stuff_hidden:1;

    /* indicates an error state */
    int                     in_error:1;

    /* this flags that flexing memory has started */
    int                     flex_memory:1;

    /* this flags that flexible memory is not needed */
    int                     disable_flex:1;

    /* this flags that a disc full error has already been notified */
    int                     disc_full_already:1;

    /* this flags that we are ignoring CVS files in Copy and CopyLocal */
    int                     auto_skip_cvs:1;
} action_environment;

BOOL message_event_handler( wimp_eventstr *event, void *environment );
void option_menu_handler( action_environment *env, char *hit );
BOOL idle_event_handler(dbox db, void *event, void *handle);
void switch_dbox_on_off( action_environment *env, int direction, int delay );
void switch_to_reading( action_environment * );
void switch_to_writing( action_environment * );
void show_faster_stuff( action_environment *env );
void toggle_faster( action_environment *env );
extern void set_top_info_field_with_current_info(action_environment *env, char *token1, char *token2);

extern const char *last_top_info_field;
extern action_environment env;
extern int __root_stack_size;


/*
     Delays for displaying verbose box and removing non-verbose box
     in 1/100ths of a second
*/
#define Display_Delay 0
#define Remove_Delay  200


/*
     Dialogue box fields
*/
#define   Bottom_Info_Path      2
#define   Top_Progress_Field    3
#define   Bottom_Progress_Field 4
#define   Top_Progress_Line     5
#define   Bottom_Progress_Line  6
#define   Abort_Button          7
#define   No_Skip_Button        8
#define   Yes_Retry_Button      9
#define   Misc_Button           10
#define   Skip_Button           11
#define   Error_Field           12

#define   Progress_Bar          16
#define   Progress_Bar_BBox     15

/* 1 less than the space allocated for the icon's indirected string */
#define Top_Info_Field_Length   79

/*
        Window names
*/
#define MAIN_TEMPLATE_NAME      "FCount"
#define QUERY_TEMPLATE_NAME     "query"
