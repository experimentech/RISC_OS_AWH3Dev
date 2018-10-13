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
/*****************************************************************************
* $Id: ResCommon,v 4.10 2003-12-02 15:50:04 bavison Exp $
* $Name: HEAD $
*
* Author:  David Cotton
* Project: Bethany (333)
*
* ----------------------------------------------------------------------------
* Copyright [2000] Pace Micro Technology PLC.  All rights reserved.
*
* The copyright in this material is owned by Pace Micro Technology PLC
* ("Pace").  This material is regarded as a highly confidential trade secret
* of Pace.  It may not be reproduced, used, sold or in any other way exploited
* or transferred to any third party without the prior written permission of
* Pace.
*
* ----------------------------------------------------------------------------
* Purpose: This file contains source code required for the ResCommon utility.
*           This utility implements some of the functionality required for
*           the Multiple Resource sets in RISC OS ROMS (see spec 2503,027/FS).
*          This utlity scans through a set of resource directories and strips
*           out all the common files into a series of Common directories.
*
* ----------------------------------------------------------------------------
* History: See source control system log
*
*****************************************************************************/


/*****************************************************************************
* Include header files
*****************************************************************************/
/* Include Standard headers */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include <ctype.h>

/* Include RISC OS headers */
#include "kernel.h"
#include "swis.h"
#include "os.h"
#include "Global/FileTypes.h"
#include "Global/Services.h"

/* Include other headers */
#include "msgcommon.h"
#include "debuglib/debuglib.h"

/*****************************************************************************
* MACROS
*****************************************************************************/
#define MAX_TERRITORIES 10            /* As defind in the spec. */
#define MAX_OPEN_TERRITORY_FILES MAX_TERRITORIES   /* This value matches the available number of territories defined in the spec */
#define ENV_LOCALE_LIST "LocaleList"  /* name of env var holding the comma-seperated list of lcoales */
#define BUFSZ   512                   /* Old value needed by cut & paste code. */
#define MAX_PATH_SIZE BUFSZ           /* Maximum path lengths allowd in strings. */
#define filetype( object )      (((object)->loadaddr>>8)&0xFFF)

/*****************************************************************************
* New enumerated types
*****************************************************************************/
typedef unsigned int word;

/* Structure in which to hold the file information for a file */
typedef struct
{
  word loadaddr;
  word execaddr;
  word length;
  word attr;
  word type;
  char name[1];
} object;

/* The structure below defines a type that can be used to hold squash file headers as
    defined in PRM 4 Appendix E */
typedef struct
{
  char id[4];
  int size;
  int load_addr;
  int exec_addr;
  int reserved;
} squash_header_struct;


/* This structure holds the details of which files held in the resources are
    identical. */
typedef struct
{
  int   file_num[MAX_TERRITORIES];   // The file number this refers to, 0 to MAX_TERRITORIES-1
  int   array_size;                  // The number of entries in this array. -1 is a special value.
} list;

/* This structure holds a list of the above structures. This allows a number
    of resource files to be seen as being identical. Each set of identical
    resource files is held in it's own list. */
typedef struct
{
  list lists[MAX_TERRITORIES]; // There has to be a maximum of MAX_TERRITORIES list.
} list_of_lists;

list_of_lists* main_list;

/*****************************************************************************
* Constants
*****************************************************************************/


/*****************************************************************************
* File scope Global variables
*****************************************************************************/
char* supported_territories[MAX_TERRITORIES] = NULL; /* An array in which territories defined in the Env file can be stored. */
unsigned int num_of_territories = 0;                 /* The number of territories defined. */
char* root_resources_directory = NULL;
char* root_processed_directory = NULL;
char* directory_to_copy = NULL;
char* compared_files[MAX_TERRITORIES] = NULL; /* An array in which to store the filenames of the files t be compared. */
bool  verbose = false; /* Do you wish to see what it is doing */
bool  simulate = false; /* Do not actually delete any files. */
char* common_directory = NULL; /* Stores the path relating to the 'common' resource set. */
bool  uk_resources_present = false; /* Set to true if locale_list includes "UK" */

/*****************************************************************************
* Function prototypes - Private to this file
*****************************************************************************/
unsigned long int filer_object_type(const char* filename);
bool file_exists(char* filename);
char *strdup(const char *str);
bool parse_territories(char* territory_line);
bool mkdir(char *dir, int mode);
int  file_size(char *file);
char *read_env(char *variable);
bool ensure_resource_directories_exist(void);
int  get_filetype(char* obj);
void appendleaf( char *path, char *leaf );
void stripleaf( char *path );
bool compare_files(const char* filename);
bool perform_comparisons(char* path_leaf);
void descend(char *path);
bool compare_resources(void);
int  cstrcmp(const char* a, const char *b);
void help_text(void);
void exit_handler(void);
bool compare_squash_files(void);
int  return_country_number(const char* const country);

void test_file_comparisons(void);


void         main_list_create_initial(unsigned int num_of_territories);
void         main_list_initialise(list_of_lists* main_list, unsigned int num_of_territories);
void         main_list_display(list_of_lists* list_to_display, unsigned int num_of_territories);
void         main_list_display_node_num(list_of_lists* main_list_to_display, unsigned int list_to_display);
unsigned int list_create_new(list_of_lists* list_to_alter, const char char_to_enter, unsigned int num_of_territories);
void         sublist_parse(list* this_list, list_of_lists* new_list, const unsigned int* const file_line, unsigned int num_of_territories);
unsigned int main_list_count_nodes(list_of_lists* list, unsigned int num_of_territories);

void compare_file_contents(const unsigned int* const string, unsigned int num_of_territories);


/*****************************************************************************
* Functions
*****************************************************************************/




/*********************************************************************************/
/* file_exists                                                                   */
/*                                                                               */
/* This routine checks whether the passed file exists.                           */
/*                                                                               */
/* Parameters: filename  This is the filename of the file to be checked.         */
/*                                                                               */
/* Returns:    It returns true if the file exists, false otherwise (or if there  */
/*              was an error during the SWI call).                               */
/*                                                                               */
/*********************************************************************************/
bool file_exists(char* filename)
{
  _kernel_oserror *err;
  unsigned long int exists;

  dprintf(("", "file_exists()\n"));

  err = _swix( OS_File, _IN(0)|_IN(1)|_OUT(0), 5, filename, &exists);
  if (!exists || err) /* File does not exist. */
  {
    return (false);
  }
  return (true);
}




/*********************************************************************************/
/* filer_object_type                                                             */
/*                                                                               */
/* This routine returns the type of the filer object corresponding to the        */
/*  filename passed in.                                                          */
/*                                                                               */
/* Parameters: filename  This is the filename of the file to be checked.         */
/*                                                                               */
/* Returns:    It returns : 0 for no such object                                 */
/*                          1 for a file object                                  */
/*                          2 for a directory object                             */
/*                          3 for an image object                                */
/*                                                                               */
/*********************************************************************************/
unsigned long int filer_object_type(const char* filename)
{
  _kernel_oserror *err;
  unsigned long int object_type = 0;

  dprintf(("", "filer_object_type()\n"));

  assert (filename!=NULL);
  err = _swix( OS_File, _IN(0)|_IN(1)|_OUT(0), 5, filename, &object_type);
  if (err)
  {
    dprintf(("", "filer_object_type(): Error trying to find object type of file '%s'\n", filename));
  }

  return (object_type);
}





/*****************************************************************************
* strdup
*
* This routine malloc's an area for a string and copy the string in
*
* Assumptions
*  uses malloc; the memory allocated must be free'd at some point.
*
* Inputs
*  str         : The string to be copied.
*
* Outputs
*  variablename: None; str is constant and should remain unaltered.
*
* Returns
*  A pointer to the copy of the string, or NULL if the copy failed.
*****************************************************************************/
char *strdup(const char *str)
{
  char *newstr = malloc(str == NULL ? 1 : (strlen(str) + 1));

  if (newstr != NULL) {
    if (str == NULL)
      *newstr = 0;
    else
      strcpy(newstr, str);
  }
  return (newstr);
}



/*****************************************************************************
* parse_territories
*
* This routine parses any territory line passed in and strips out all the
*  territories into the global supported_territoried array.
* If the line is invalid, it retunrs false, otherwise it returns true. A
*  line is considered invalid if it is empty or contains whitespace.
*
* Assumptions
*  The global variables supported_territories[] and num_of_territories
*   will both be altered.
*
* Inputs
*  territory_line: A comma-seperated list of countries.
*
* Outputs
*  None. territory_line is a constant pointer.
*
* Returns
*  A boolean describing whether or not the territory line was parsed
*   successfully.
*****************************************************************************/

bool parse_territories(char* territory_line)
{
  char *territory = NULL;

  printf("Parsing territory line %s\n", territory_line);

  if (strlen(territory_line) < 1)
  {
    /* Line must contain something */
    return (false);
  }

  territory = strtok(territory_line, ",");
  while (territory)
  {
    printf ("territory is %s\n", territory);
    supported_territories[num_of_territories++] = strdup(territory);
    territory = strtok (NULL, ",");
  }

  printf ("%d territories detected in the territories list.\n", num_of_territories);

  return (true);
}



/*****************************************************************************
* mkdir
*
* This routine creates the directory passed in.
*
* Assumptions
*  That the directory immediately below the one to be created exists. If it
*   does not then the directory will fail to be completed.
*
* Inputs
*  dir           : A pointer to a string containing the directory to be
*                   created
*  mode          : Unused. Kept for Unix compatability.
*
* Outputs
*  Will create the directory if all conditions are met.
*
* Returns
*  A boolean describing whether or not the swi call was called successfully.
*
*****************************************************************************/
bool mkdir(char *dir, int mode)
{
  _kernel_swi_regs reg;

  reg.r[0] = 8;
  reg.r[1] = (int) dir;
  reg.r[4] = 0;
  if (_kernel_swi(OS_File, &reg, &reg))
  {
    return (true);
  }
  return (false);
}




/*****************************************************************************
* file_size
*
* This routine returns the size of the file represented by the filename
*  passed in.
*
* Assumptions
*  This routine falls foul of the normal RISC OS limitation of a file
*   not being larger than the size of an unsigned integer.
*
* Inputs
*  file          : A pointer to the filename
*
* Outputs
*  None
*
* Returns
*  An integer holding the size of the returned file, or -1 if the operation
*   failed.
*
*****************************************************************************/
int file_size(char *file)
{
  _kernel_swi_regs reg;

  reg.r[0] = 23;		/* no paths */
  reg.r[1] = (int) file;
  _kernel_swi(OS_File, &reg, &reg);

  return (reg.r[0] == 1 ? reg.r[4] : -1);
}




/*****************************************************************************
* read_env
*
* This routine reads an environment variable in to a malloced string
*
* Assumptions
*  None
*
* Inputs
*  variable      : The system variable to be read.
*
* Outputs
*  None
*
* Returns
*  A pointer a string containing the contents of the system variable; if
*   the operation fails (for instance the system variable passed in does
*   not exist) then it returns NULL.
*
*****************************************************************************/
char *read_env(char *variable)
{
  char *var = NULL;
  char *cp = NULL;

  if ((var = getenv(variable)) != NULL)
    cp = strdup(var);

  return (cp);
}





/*****************************************************************************
* ensure_resource_directories_exist
*
* This routine scans through the list of territories and ensures that the
*  required resource directories all exist. It does this by checking that
*  <root_resources_directory>.<territory_name> is a valid directory.
*
* Assumptions
*  There should be no effect outside this routine.
*
* Inputs
*  None.
*
* Outputs
*  None.
*
* Returns
*  A boolean, true if the resource directories existed in the correct
*   location, false otherwise.
*****************************************************************************/
bool ensure_resource_directories_exist(void)
{
  unsigned int loop;
  char buffer[BUFSZ]; /* Nasty hardcoded value */
  for (loop=0; loop < num_of_territories; loop++)
  {
    sprintf(buffer, "%s.%s", root_resources_directory, supported_territories[loop]);
    printf ("Checking for %s.\n", buffer);
    if (filer_object_type(buffer) != 2)
    {
      printf("Warning: %s is not a directory.\n", buffer);
      return (false);
    }
  }

  return (true);
}







/*****************************************************************************
* get_filetype
*
* This routine returns the filetype of the object to pointed to by obj.
*
* Assumptions
*  It is assumed that the object pointed to by obj exists and is a file; if
*   not then -1 is returned.
*
* Inputs
*  obj :         The object we require the filetype of.
*
* Outputs
*  None.
*
* Returns
*  The filetype, or -1 if the file does not exist.
*****************************************************************************/

int get_filetype(char* obj)
{
  if (file_exists(obj))
  {
    int type, load_addr;
    _swi( OS_File, _IN(0)|_IN(1)|_OUT(2), 17, obj, &load_addr );
    type = (load_addr>>8)&0xFFF;
    return (type);
  }
  else
  {
    return (-1);
  }
}







/*****************************************************************************
* appendleaf
*
* This routine appends the leaf passed in onto the end of the path.
*
* Assumptions
*  This routine assumes that the area of memory that holds path is large
*   enough to hold the alterd string. No bounds checking is performed.
*
* Inputs
*  path :        The path for the leaf to be appended to.
*  leaf :        The leafname to be appended.
*
* Outputs
*  The new path with the leaf appended.
*
* Returns
*  None.
*****************************************************************************/
void appendleaf( char *path, char *leaf )
{
  strcat( path, "." );
  strcat( path, leaf );
}





/*****************************************************************************
* stripleaf
*
* This function strips the last leaf segment off the path passed in.
* The filename seperator is taken to be the '.' character
*
* Assumptions
*  If there are no seperator ('.') characters in te string, then the string
*   is unaltered.
*
* Inputs
*  path :        The path to be truncated.
*
* Outputs
*  path :         The truncated path.
*
* Returns
*  None.
*****************************************************************************/
void stripleaf( char *path )
{
  char *sep = strrchr( path, '.' );

  if (sep != NULL)
  {
    *sep = '\0';
  }
}





/*****************************************************************************
* compare_files
*
* This routine takes the path passed in and compares it with the other
*  resource sets. E.g. if a file ...UK.Foo was passed in, and the LocaleList
*  was set to UK,France,Germany it would compare ...Common.Foo, ...France.Foo
*  and ...Germany.Foo.
* The UK territory, being he first in the localelist, was used as te base for
*  the Common directory, and therefore must be identical and is not compared
*  for that reason.
*
* Assumptions
*  This routine alters the global array compared_files[], which contains the
*   paths to all the files to be compared.
*  It also deletes the file in the 'common' directory if it was not common, or
*   in the territory-specific directoties if it was common.
*
* Inputs
*  filename:     The name of the file to be compared.
*
* Outputs
*  None.
*
* Returns
*  It returns true if the file exists in all possible resource sets and they
*   match, false otherwise
*****************************************************************************/
bool compare_files(const char* filename)
{
  char buffer[255];
  char* path_segment = NULL;
  unsigned int length;
  unsigned int loop;

  /* Get the segment of the path after the territory. */
  length = strlen(root_resources_directory);
  path_segment = (char*)filename+length;
  length = strlen(supported_territories[0]);
  path_segment+=length+2;

  /* Now create the other filenames using the known path. */
  for (loop=0; loop < num_of_territories; loop++)
  {
    if (strcmp(supported_territories[loop], directory_to_copy) != 0) /* Ignore the one we copied, as files must be the same. */
    {
      sprintf(buffer, "%s.%s.%s", root_resources_directory, supported_territories[loop], path_segment);
      compared_files[loop] = strdup(buffer);
    }
    else
    {
      /* Store the reference file */
      compared_files[loop] = strdup((char*)filename);
    }
  }

  /* Display all the files that will be parsed if the verbose flag is set. */
  if (verbose)
  {
    for (loop=0; loop < num_of_territories; loop++)
    {
       printf ("%s\n", compared_files[loop]);
    }
  }

  /* Perform the comparisons...*/
  perform_comparisons(path_segment);

  /* Now free the memory held by all the files... */
  for (loop=0; loop < num_of_territories; loop++)
  {
    if (compared_files[loop])
    {
      free (compared_files[loop]);
      compared_files[loop] = NULL;
    }
  }

  return (false);
}





/*****************************************************************************
* perform_comparisons
*
* This routine opens all the files held in the compared_files array and
*  attempts to compare them. It checks files are identical by the following
*  means:
*   1) Compare filetypes and sizes.
*   2) Open all the files
*   3) Read all the files byte-by-byte, compareing them, until a difference
*       is detected or the end of the file is reached.
*   4) Close all the files.
* Note that files of type Squash are treated differently due to the fact
*  that identical files that have been squashed at different times will end
*  up with different header data.
* If a file is identical in (say) UK and France but not in Germany, then the
*  file will be placed in a UK,France directory and also in the Germany
*  directory. This reduces the commanlity of the files to the minimum possible.
* If a file is identical in all files, then it gets placed into a directory
*  that is common between all resource sets.
*
* Assumptions
*  That the number of files to be opened is less than MAX_OPEN_TERRITORY_FILES.
*
* Inputs
*  None.
*
* Outputs
*  None.
*
* Returns
*  This routine returns true if all the files are the same, false otherwise.
*****************************************************************************/
bool perform_comparisons(char* path_leaf)
{
  FILE* file_handles[MAX_OPEN_TERRITORY_FILES]; /* An array to hold all the file handles */
  unsigned int loop;
  bool file_matches = true;
  unsigned int main_list_loop;
  unsigned int filesize[MAX_OPEN_TERRITORY_FILES] = 0;
  unsigned int filetype[MAX_OPEN_TERRITORY_FILES] = 0;
  unsigned int file_byte_count = 0; /* Stores the number of bytes we are through the file. */

  assert (path_leaf != NULL);

  /* Initialise all the memory */
  main_list = malloc(sizeof(list_of_lists));
  main_list_initialise(main_list, num_of_territories);
  main_list_create_initial(num_of_territories);  /* Create a list with all files being identical. */

  /* Ensure that all the files exist and grab their filesizes and filetypes.*/
  for (loop=0; loop < num_of_territories; loop++)
  {
    unsigned int files_exist[MAX_OPEN_TERRITORY_FILES]; /* Store whether the files exists or not. */
    assert (compared_files[loop] != NULL); /* Check we are not going to try to open a NULL pointer... */

    /* Ensure that all the files exist. */
    if (!file_exists(compared_files[loop]))
    {
      if (verbose)
        printf("%s does not exist.\n", compared_files[loop]);
      files_exist[loop] = 0;
      return (false);
    }
    else
    {
      files_exist[loop] = 1;
    }

    /* Compare the filetypes and filesizes */
    filetype[loop] = get_filetype(compared_files[loop]);
    filesize[loop] = file_size(compared_files[loop]);
  }

  /* Now set up the initial list with the data held in the filetype and filesizes. */
  compare_file_contents(filetype, num_of_territories);
  compare_file_contents(filesize, num_of_territories);

  /* Open all the files. */
  for (loop=0; loop < num_of_territories; loop++)
  {
    assert (compared_files[loop] != NULL); /* Check we are not going to try to open a NULL pointer... */
    /* Open the file.. */
    if ((file_handles[loop]=fopen(compared_files[loop],"r")) == NULL)
    {
      if (verbose)
        printf("Error opening file %s for reading.\n", compared_files[loop]);
      return (false); /* If we can't open it, we are not bothered... (atm neway) */
    }
  }

  /* Scan through all the files on a byte-by-byte basis, comparing them. */
  while (!feof(file_handles[0]) && file_matches)
  {
    unsigned int bytes[MAX_OPEN_TERRITORY_FILES+1]; /* To hold the bytes from all the files... */
    bool ignore_line = false; /* Set ig we wish to ignire a line of a file for some reason. */
    file_byte_count++;

    /* Another check - if the files are squash files, then they will always be
       different due to headser differences. Ignore the headers. */
    if (filetype[0] == FileType_Squash)
    {
      if (file_byte_count < sizeof(squash_header_struct))
      {
        ignore_line = true;
      }
    }

    /* In the future we may wish to treat spritefiles differently. This is a
        conditional to check for the presence of a spritefile. */
    if (filetype[0] == FileType_Sprite)
    {
      /* Do some magic munging here. We could possibly split all common sprites
          held within the spritefiles into a 'common' file to save ROM space. */
    }

    /* Fill up the string with the bytes from the files. */
    if (!ignore_line) /* We wish to diff this line. */
    {
      for (loop=0; loop<num_of_territories; loop++)
      {
        bytes[loop] = (unsigned int) getc(file_handles[loop]);
      }
      bytes[loop+1]=(unsigned int)'\0';

      /* Perform the comparisons */
      compare_file_contents(bytes, num_of_territories);

      /* If we have n lists, they must all be different files. No need to parse anymore. */
      if (main_list_count_nodes(main_list, num_of_territories) == num_of_territories)
      {
        if (verbose)
        {
          printf ("All files are different. Exiting early.\n");
        }
        break;
      }
    }
  }

  /* Display the results */
  if (verbose)
  {
    printf("List condition after parsing all the files (file %s)...\n", path_leaf);
    main_list_display(main_list, num_of_territories);
  }

  /* Collate the result into a series of directories that the files have to be
      copied into. */
  for (main_list_loop=0; main_list_loop<num_of_territories; main_list_loop++)
  {
    char directory_string[(MAX_TERRITORIES*2)+1]; /* Each territory can have two characters, and the string needs a terminator */
    char destination_directory[MAX_PATH_SIZE];    /* Nasty hardcoded limit */
    char buffer[MAX_PATH_SIZE];                   /* Another nasty hardcoded limit. */
    list *this_list = &main_list->lists[main_list_loop];

    /* Create the directory string relating to this particular list of
        directories */
    strcpy(directory_string,""); /* Initialise the string */
    if (this_list->array_size > 0) /* We do not wish to display empty lists. */
    {
      unsigned int sublist_loop;
      for (sublist_loop=0; sublist_loop < this_list->array_size; sublist_loop++)
      {
        if (this_list->file_num[sublist_loop] >= 0) /* Do not display empty locations */
        {
          char tempstr[7];
          int terr_number = return_country_number(supported_territories[this_list->file_num[sublist_loop]]);
          //printf (" %d (%s, country code %d)", this_list->file_num[sublist_loop], supported_territories[this_list->file_num[sublist_loop]], terr_number);
          if (!uk_resources_present && this_list->file_num[sublist_loop] == 0)
          {
            /* We wish to add UK territory number (01) onto the first territory */
            sprintf(tempstr, "%02d01", terr_number);
            strcat(directory_string, tempstr);
          }
          else
          {
            sprintf(tempstr, "%02d", terr_number);
            strcat(directory_string, tempstr);
          }
        }
      }

      /* printf ("directory string is %s\n", directory_string); Debug line */

      /* If the directory string is the same as the common one, then change
          it's name to 'common' */
      if (strcmp(directory_string, common_directory) == 0) /* They match */
      {
        assert (common_directory != NULL);
        // printf("%s is the common resource set. Renaming the directory path to 00.\n", directory_string);
        strcpy(directory_string, "common");
      }

      /* Create the directory and copy the resources over. */
      sprintf(destination_directory, "%s.%s", root_processed_directory, directory_string);
      mkdir (destination_directory, 0);
      for (sublist_loop=0; sublist_loop < this_list->array_size; sublist_loop++)
      {
        if (this_list->file_num[sublist_loop] >= 0) /* Do not display empty locations */
        {
          char dir_to_create[MAX_PATH_SIZE];
          /* Ensure the relevant directory exists. */
          sprintf(dir_to_create, "mkdir -p %s.%s", destination_directory, path_leaf);
          stripleaf(dir_to_create);
          system(dir_to_create);
          /* Copy the file over. */
          sprintf(buffer, "copy %s.%s.%s %s.%s r~v~cf", root_resources_directory, supported_territories[this_list->file_num[sublist_loop]], path_leaf, destination_directory, path_leaf);
          //printf("Running sys command %s\n", buffer);
          system(buffer);
        }
      }
    }
  }

  /* Close all the files */
  for (loop=0; loop < num_of_territories; loop++)
  {
    if (file_handles[loop])
    {
      fclose(file_handles[loop]);
    }
  }

  /* Free off the memory. */
  free (main_list);

  return (file_matches);
}





/*****************************************************************************
* descend
*
* This routine descends into the directory path passed in, reading all the
*  files and directories held within it. It can be caled recursively to scan
*  a whole directory structure.
* Any files that are in the path directory are compared using subsidiary
*  routines.
*
* Assumptions
*  That BUFSZ is large enough to hold any possible path.
*
* Inputs
*  path:         The path to be recursed from.
*
* Outputs
*  None.
*
* Returns
*  None.
*****************************************************************************/
void descend(char *path)
{
  char *buf = malloc( BUFSZ );
  int offset = 0;

  if ( buf != NULL )
  {
    do
    {
      object *op = (object *)buf;
      int nread;

      printf ("Comparing files in path %s\n", path);
      _swi( OS_GBPB, _IN(0)|_IN(1)|_IN(2)|_IN(3)|_IN(4)|_IN(5)|_IN(6)|_OUT(3)|_OUT(4),
              10, path, buf, 80, offset, BUFSZ, 0, &nread, &offset );

      while ( nread > 0 )
      {
        switch ( op->type )
        {
          case 1:
            /* Text file found so scan it for tags. */
            appendleaf( path, op->name );
            if (compare_files(path))
            {
            }
            else
            {
              //printf ("Not matched: %s\n", path);
            }
            stripleaf( path );
            break;

          case 2:
            /* Directory found so descend into it.
             */
            appendleaf( path, op->name );
            descend( path );
            stripleaf( path );
            break;

          default:
            printf("Don't know how to process object type %d\n", op->type );
      }

        op = (object *)(((int)(op->name)+strlen(op->name)+4)&~3);
        nread -= 1;
      }
    } while ( offset != -1 );

    free( buf );
  }
  else
  {
    printf("Couldn't allocate enough memory\n" );
    exit (EXIT_FAILURE);
  }
}







/*****************************************************************************
* compare_resources
*
* This routine is the main routine that is called when attempting to compare
*  a set of resources.
*
* Assumptions
*  That root_resources_directory exists, and that BUFSZ is large enoguh to hold a
*   string of length strlen(root_resources_directory)+strlen(".Common"). Because it is
*   used within the descend() routine to hold the curren path, then BUFSZ will
*   have to be large enough to hold the longest path in the directory
*   structure below root_resources_directory.
*
* Inputs
*  None.
*
* Outputs
*  buffer :      This gets altered  range of outputs, etc. List variables in
*                the same order that they appear in the function definition.
*
* Returns
*  This routine returns true.
*****************************************************************************/

bool compare_resources(void)
{
  char buffer[BUFSZ];

  assert(root_resources_directory);

  /* Recurse down the directory structure... */
  sprintf(buffer, "%s.%s", root_resources_directory, supported_territories[0]);
  descend(buffer);

  return (true);
}




/*****************************************************************************
* cstrcmp
*
* This routine compares two string caselessly.
*
* Assumptions
*  State any assumptions and side effects (eg. globals changed)
*
* Inputs
*  a:            The first string to be compared.
*  b:            The second string to be compared.
*
* Outputs
*  None.
*
* Returns
*  0 if both strings are NULL, or both strings are (ignoring case) identical.
*  -1 if one (but not both) of the strings are NULL.
*  Any other value if the strings are different.
*****************************************************************************/

int cstrcmp(const char *a, const char *b)
{
  int d;

  if (a == NULL && b == NULL)
    return (0);

  if (a == NULL || b == NULL)
    return (-1);

  while (*a || *b) {
    d = tolower(*(a++)) - tolower(*(b++));
    if (d)
      return (d);
  }
  return (0);
}





/*****************************************************************************
* help_text
*
* Display a suitable help text.
*
* Assumptions
*  There are no assumptions.
*
* Inputs
*  None.
*
* Outputs
*  None.
*
* Returns
*  None.
*****************************************************************************/

void help_text(void)
{
  printf ("ResCommon\n");
  printf ("\n");
  printf ("Usage: ResCommon <root resources dir> <root processed dir> [-t <territory_list>] [-v -h -s]\n");
  printf ("Commands: <root resources dir> Where to get the resources files for each territory from.\n");
  printf ("Commands: <root processed dir> Where to place all the resource files after commanlities have been detected.\n");
  printf ("Options:  -t <territory_list>  A comma-seperated list of territories to use.\n");
  printf ("          -v                   Verbose. Display verbose output on what the utility is doing.\n");
  printf ("          -h                   Help. Display help text.\n");
  printf ("          -s                   Simulate. Do not delete any files.\n");
  printf ("\n");
  printf ("This utility looks for common resources held in different territories and places them in relevant directories. \n");
  printf ("This allows as may different resource sets as possible to be squeezed into one ROM image.\n");
  printf ("\n");
}





/*****************************************************************************
* main
*
* Main routine. This routine parses the command line argument passed in, sets
*  up appropriate data needed for the program and starts off the comparison
*  of the resources.
*
* Assumptions
*  None.
*
* Inputs
*  argc:         A count of the number of command-line arguments.
*  argv:         A vector containing the command line arguments.
*
* Outputs
*  None.
*
* Returns
*  EXIT_FAILURE if the program failed for some reason, otherwise,
*   EXIT_SUCCESS
*****************************************************************************/
int main(int argc, char **argv)
{
  char* locale_list = NULL;
  unsigned int i, loop;

  /* Define an atexit handler */
  atexit(exit_handler);

  if (argc < 3)
  {
    fprintf(stderr, "Usage: ResCommon <root resourcesd dir> <root processed dir> [-t <territory_list>] [-v -h -s]\n");
    exit (EXIT_FAILURE);
  }

  for (i = 1; i < argc; i++)
  {
    // printf("arg %d: %s\n", i, argv[i]);
    if ((cstrcmp(argv[i], "-h") == 0) || (cstrcmp(argv[i], "-help") == 0))
    {
      help_text();
      exit(EXIT_FAILURE);
    }
    if ((cstrcmp(argv[i], "-v") == 0) || (cstrcmp(argv[i], "-verbose") == 0))
    {
      verbose = TRUE;
    }
    if ((cstrcmp(argv[i], "-t") == 0) || (cstrcmp(argv[i], "-territories") == 0))
    {
      /* The next arg should be a comma-separated territory list. */
      char* list = NULL;
      list = strdup(argv[++i]);
      parse_territories(list);
      if (list)
      {
        free (list);
        list = NULL;
      }
    }
    else
    {
      if ((cstrcmp(argv[i], "-s") == 0) || (cstrcmp(argv[i], "-simulate") == 0))
      {
        simulate = TRUE;
      }
    }
  }

  /* Read the required starting directory from the command line. */
  root_resources_directory = strdup(argv[1]);
  if (verbose)
    printf("root resources directory is %s\n", root_resources_directory);

  /* Read the required starting directory from the command line. */
  root_processed_directory = strdup(argv[2]);
  if (verbose)
    printf("root processed directory is %s\n", root_processed_directory);

  /* Ensure that root resources directory is a directory. */
  if (filer_object_type(root_resources_directory) != 2)
  {
    fprintf(stderr, "Error: %s should be a directory.\n", root_resources_directory);
    exit (EXIT_FAILURE);
  }
  /* Ensure that root processed directory is a directory. */
  if (filer_object_type(root_processed_directory) != 2)
  {
    fprintf(stderr, "Error: %s should be a directory.\n", root_processed_directory);
    exit (EXIT_FAILURE);
  }

  /* We need to see if a locale_list has been defined. If it has, we need to split it into a list of locales.
      Only do this if a valid list was not passed in on the command line. */
  if (num_of_territories == 0 && ((locale_list = read_env(ENV_LOCALE_LIST)) != NULL))
  {
    if (!parse_territories(locale_list))
    {
      /* An error occured whilst parsing the loale list. */
      printf("Malformed Locale list detected.");
      exit (EXIT_FAILURE);
    }
    free (locale_list);
    locale_list = NULL; /* locale_list is no longer needed */
  }

  /* If there are no territories something hs gone wrong. Flag this up. */
  if (num_of_territories == 0)
  {
    /* If there was not a locale list in env or on command line, report it and quit. */
    fprintf(stderr, "No locale list present.\n");
    exit (EXIT_FAILURE); /* Success as the program should do nothing if there is no localelist. */
  }

  /* One territory is a special case - just copy the resources as there are
no comparisons to be made. This will speed up single-territory builds. */
  if (num_of_territories == 1)
  {
    char buffer[MAX_PATH_SIZE];                   /* Another nasty hardcoded limit. */
    char dir_to_create[MAX_PATH_SIZE];
    printf("There is only one territory. Copying from resources to processed and exiting.\n");
    /* Ensure the relevant directory exists. */
    sprintf(dir_to_create, "mkdir -p %s.%s", root_processed_directory, "Common");
    if (verbose) printf("Running sys command %s\n", dir_to_create);
    system(dir_to_create);
    /* Copy the file over. */
    sprintf(buffer, "copy %s.%s %s.%s r~v~cf", root_resources_directory, supported_territories[0],  root_processed_directory, "Common");
    if (verbose) printf("Running sys command %s\n", buffer);
    system(buffer);
    exit (EXIT_SUCCESS);
  }

  /* See if the UK territory (01) is in the list. If it is not, map one of
the other territories onto it. This is because a ROM build should always
have a UK territory in it (the Kernel default value for territory is 01, so
doing a reset on a build with no UK resources in causes ROM initialisation to
fail). Mapping a territory to UK (for example making Germany 0701) means that
the ROM thinks that the UK resources are present, although in reality it is
using the German resource set. This will allow the NC to boot correctly after
a delete-poweron has been performed. */
  for (loop=0; loop < num_of_territories; loop++)
  {
    printf("Supported territory %d is %s\n", loop, supported_territories[loop]);
    if (cstrcmp(supported_territories[loop],"UK") == 0) /* UK resource set is present */
    {
      printf("UK resource set present in locale list.\n");
      uk_resources_present = true;
    }
  }

  /* Create the 'common_directory' string */
  if (num_of_territories == 1)
  {
    common_directory = malloc (3);
    sprintf(common_directory, "%02d", return_country_number(supported_territories[0]));
  }
  else
  {
    unsigned int loop = 0;
    common_directory = malloc ((num_of_territories*3)+1);
    strcpy(common_directory, "");
    for (loop=0; loop < num_of_territories; loop++)
    {
      char tempstr[5];
      int terr_number = return_country_number(supported_territories[loop]);
      sprintf(tempstr, "%02d", terr_number);
      strcat(common_directory, tempstr);
      if (!uk_resources_present && loop == 0)
      {
        /* Add the UK territory onto the string */
        strcat(common_directory, "01");
      }
    }
  }
  printf("Common directory is %s\n", common_directory);

  /* Ensure that the resource directories exist. */
  if (!ensure_resource_directories_exist())
  {
    printf("Not all resource directories exist.\n");
    exit (EXIT_FAILURE);
  }

  /* And now do the comparisons... */
  compare_resources();
}




/*****************************************************************************
* exit_handler
*
* This function can be used to clear up any outstanding memory left
*  afer the program has finished. It should only be used to delete
*  memory that is needed throughout the lifetime of the program, for
*  example the locale_list.
*
* Assumptions
*  There are no assumptions.
*
* Inputs
*  None.
*
* Outputs
*  None.
*
* Returns
*  None.
*****************************************************************************/
void exit_handler(void)
{
  unsigned int loop;

  /* Free the locale array if it has not already been free'd. */
  if (num_of_territories != 0)
  {
    for (loop=0; loop < num_of_territories; loop++)
    {
      if (compared_files[loop]) /* Memory has not been free'd. */
      {
        free (compared_files[loop]);
        compared_files[loop] = NULL;
      }
    }
    num_of_territories = 0;
  }

  /* Free the directory_to_copy memory */
  if (directory_to_copy)
  {
    free (directory_to_copy);
    directory_to_copy = NULL;
  }

  /* Free the root resources directory */
  if (root_resources_directory)
  {
    free (root_resources_directory);
    root_resources_directory = NULL;
  }

  /* Free the root processed directory */
  if (root_processed_directory)
  {
    free (root_processed_directory);
    root_processed_directory = NULL;
  }

  /* Free the common directory */
  if (common_directory)
  {
    free (common_directory);
    common_directory = NULL;
  }
}








/*****************************************************************************
* compare_file_contents
*
* This routine compares the contents of a 'line' of bytes across the files
*  that are currently open. The contents of the file are held in array of
*  unsigned integers, which means that things other than file contents can be
*  compared (for instance this routine is also used to compare filetypes and
*  filesizes).
*
* Assumptions
*  This routine assumes that all the data being passed in is filled in as
*   appropriate; no run-time checks are performed to ensure this.
*
* Inputs
*  uint* file_contents: A pointer to an array of integers comprising the data
*                       that is to be compared.
*  uint num_of_territories: The number of territories that are held within the
*                       data array.
*
* Outputs
*  The contents of the global main_list array is altered.
*
* Returns
*  None.
*****************************************************************************/
void compare_file_contents(const unsigned int* const file_contents, unsigned int num_of_territories)
{
  unsigned int main_list_loop;
  unsigned int file_contents_loop;
  bool file_contents_identical = true; /* set to true if all bytes in the file_contents are the same. */
  list_of_lists* swap_ptr; /* Used as a scratch ptr to aid swapping lists */

  /* Create a temp list which data can be stored in. */
  list_of_lists* temp_list = malloc(sizeof(list_of_lists));

  main_list_initialise(temp_list, num_of_territories);

  /* Quick check: if all bytes in the file_contents are the same, then the list must remain identical. */
  for (file_contents_loop=0; file_contents_loop<num_of_territories; file_contents_loop++)
  {
    if (file_contents_loop > 0)
    {
      if (file_contents[file_contents_loop] != file_contents[file_contents_loop-1])
      {
        file_contents_identical=false;
        break; // Quit loop early - we have proved file_contents is not identical.
      }
    }
  }

  /* Iterate through all the main lists. */
  if (!file_contents_identical)
  {
    for (main_list_loop=0; main_list_loop < num_of_territories; main_list_loop++)
    {
      list *this_list = &main_list->lists[main_list_loop];
      sublist_parse(this_list, temp_list, file_contents, num_of_territories);
    }

    /* Copy the data from the temp list to the main list. Do this by swapping the pointers. */
    swap_ptr = main_list;
    main_list = temp_list;
    temp_list = swap_ptr;
  }

  /* Free up the memory holding the temporary list */
  free (temp_list);
}




#ifdef INCLUDE_OLD_DEBUG_CODE
/* The code below is a wrapper routne that I used to test some of the core
functions within this code. This routine has not been run for some time, but
I have left it in as it may be of use to maintaners of code in the future. */


static char *test_array[] =
{
"AAAAA", /* Should all be in the same list. */
"AABBB", /* 2 lists  0,1   and  2,3,4 */
"ABBBB", /* 3 lists  0  1   and 2,3,4 */
"ABBCB", /* 4 lists  0  1  2,4 and 3 */
"ABCDD", /* 4 lists  0  1  2  and 3,4 */
"BCDRR", /* 4 lists  0  1  2  and 3,4 */
"ABCDE", /* 5 lists  0  1  2  3  and 4 */
"QQQQQ", /* Should not have to parse this line. */
"ADSFC",  /* Or this one...*/
""
};


void test_file_comparisons(void)
{
  unsigned int file_line = 0;
  unsigned int num_territories = 5; /* This hould be passed in as a parameter */

  main_list = malloc(sizeof(list_of_lists));

  main_list_initialise(main_list, num_of_territories);

  /* Create a list with all files being identical. */
  main_list_create_initial(num_of_territories);  /* Create a list with all files being identical. */

  /* Create a new node inthe main list */
  list_create_new(main_list, 'a', num_of_territories);

  /* Now scan through the file line by line, altering the list as appropriate. */
  file_line = 0;
  while (test_array[file_line])
  {
    unsigned int main_list_loop;
    list_of_lists* swap_ptr;
    /* Create a temp list which data can be stored in. */
    list_of_lists* temp_list = malloc(sizeof(list_of_lists));
    main_list_initialise(temp_list, num_of_territories);

    printf ("\n\nParsing string %s\n", test_array[file_line]);

    /* Iterate through all the main lists. */
    for (main_list_loop=0; main_list_loop < num_of_territories; main_list_loop++)
    {
      list *this_list = &main_list->lists[main_list_loop];
      sublist_parse(this_list, temp_list, (unsigned int*) test_array[file_line], num_of_territories);
    }

    /* Display it after the alterations... */
    main_list_display(temp_list, num_of_territories);

    /* Copy the data from the temp list to the main list. Do this by swapping the pointers. */
    swap_ptr = main_list;
    main_list = temp_list;
    temp_list = swap_ptr;
    free (temp_list);

    /* If we have n lists, they must all be different files. No need to parse anymore. */
    if (main_list_count_nodes(main_list, num_of_territories) == num_territories)
    {
      printf ("All files are different. Exiting early.\n");
      break;
    }

    file_line++;
  }

  /* Free off the memory. */
  free (main_list);
}

#endif  /* INCLUDE_OLD_DEBUG_CODE */




/* This routine initialises the lists ready for use. */
void main_list_initialise(list_of_lists* main_list, unsigned int num_of_territories)
{
  unsigned int main_list_loop;
  /* Initialise all the lists held in the main list */
  for (main_list_loop=0; main_list_loop<num_of_territories; main_list_loop++)
  {
    list *this_list = &main_list->lists[main_list_loop];
    unsigned int sublist_loop;
    /* Initialise all the sub-lists */
    for (sublist_loop=0; sublist_loop<num_of_territories; sublist_loop++)
    {
      this_list->file_num[sublist_loop] = -1;
    }
    this_list->array_size = -1;
  }
}






/* This routine creates an initial list with the first node pointing to all files. */
void main_list_create_initial(unsigned int num_of_territories)
{
  unsigned int sublist_loop;
  list *this_list = &main_list->lists[0];
  /* Initialise all the sub-lists */
  for (sublist_loop=0; sublist_loop<num_of_territories; sublist_loop++)
  {
    this_list->file_num[sublist_loop] = sublist_loop;
  }
  this_list->array_size = num_of_territories;
}




/* This routine displays all the nodes in the main list.*/
void main_list_display(list_of_lists* list_to_display, unsigned int num_of_territories)
{
  unsigned int main_list_loop;
  for (main_list_loop=0; main_list_loop<num_of_territories; main_list_loop++)
  {
    main_list_display_node_num(list_to_display, main_list_loop);
  }
}




/* This routine returns the number of filled nodes in the passed in list. */
unsigned int main_list_count_nodes(list_of_lists* list_to_count, unsigned int num_of_territories)
{
  unsigned int main_list_loop;
  unsigned int count = 0;

  for (main_list_loop=0; main_list_loop<num_of_territories; main_list_loop++)
  {
    list *this_list = &list_to_count->lists[main_list_loop];
    if (this_list->array_size > 0)
    {
      count++;
    }
  }

  return (count);
}



/* This routine displays the information held in a specific node of the main list. */
void main_list_display_node_num(list_of_lists* main_list_to_display, unsigned int list_to_display)
{
  unsigned int sublist_loop;
  list *this_list = &main_list_to_display->lists[list_to_display];
  if (this_list->array_size > 0) /* We do not wish to display empty lists. */
  {
    printf ("main_list_display_node_num(): List %d contains %d nodes:", list_to_display, this_list->array_size);
    /* Loop through all the elements in the loop */
    for (sublist_loop=0; sublist_loop < this_list->array_size; sublist_loop++)
    {
      if (this_list->file_num[sublist_loop] >= 0) /* Do not display empty locations */
      {
        printf (" %d (%s)", this_list->file_num[sublist_loop], supported_territories[this_list->file_num[sublist_loop]]);
      }
    }
    printf("\n");
  }
}




/* This routine creates a new main list.
   It returns the number of the created list.  */
unsigned int list_create_new(list_of_lists* list_to_alter, const char char_to_enter, unsigned int num_of_territories)
{
  unsigned int pos_created = 0;
  unsigned int list_loop;

  /* Find an empty list. */
  for (list_loop=0; list_loop<num_of_territories; list_loop++)
  {
    list *this_list = &list_to_alter->lists[list_loop];
    //printf("list_create_new(): this_list->array_size = %d\n", this_list->array_size);
    if (this_list->array_size == -1)
    {
      //printf("list_create_new(): Creating an array at position %d\n", list_loop);
      pos_created = list_loop;
      break;
    }
  }

  return (pos_created);
}



/*
  We use arrays rather than linked lists for two reasons:
     *) Linked lists need memory allocations, node creation and node destruction, which can be time-consuming.
     *) We know that there only needs to be a maximum of n nodes, where n is the number of territories being supported.
  This means that we waste a small amount of memory, but the build should go quicker without the extra memory allocaions.
*/


/* This routine scans through the current main list and creates a relevent new list. */
void sublist_parse(list* this_list, list_of_lists* new_list, const unsigned int* const file_line, unsigned int num_of_territories)
{
  unsigned int char_array[MAX_TERRITORIES];
  bool char_array_pos_filled[MAX_TERRITORIES] = false;

  if (this_list->array_size > 0) /* Ensure this list has some entries... */
  {
    unsigned int sublist_loop;

    /* We now wish to scan through all the entries in this list */
    for (sublist_loop=0; sublist_loop < this_list->array_size; sublist_loop++)
    {
      int num = this_list->file_num[sublist_loop];
      unsigned int main_list_loop;
      signed int char_already_entered=-1;
      // printf ("sublist_parse(): %d (corresponding char is %c)\n", num, (char)file_line[num]);

      /* Is the character already held in one of the lists? */
      for (main_list_loop=0; main_list_loop<num_of_territories; main_list_loop++)
      {
        list *this_list = &new_list->lists[main_list_loop];
        if (this_list->array_size > -1) /* The list is not empty */
        {
          unsigned int sublist_loop;
          for (sublist_loop=0; sublist_loop<this_list->array_size; sublist_loop++)
          {
            if (char_array_pos_filled[main_list_loop] && char_array[main_list_loop] == file_line[num])
            {
              char_already_entered = main_list_loop;
              //printf("sublist_parse(): char %c has already been entered at pos %d\n", file_line[num], main_list_loop);
              break; /* We have found it, so quit the loop early. */
            }
          }
        }
      }

      if (char_already_entered >= 0)
      {
        //printf("char %c has already been entered at pos %d\n", file_line[num], char_already_entered);
        new_list->lists[char_already_entered].file_num[new_list->lists[char_already_entered].array_size++] = num;
      }
      else
      {
        /* Create another list. */
        unsigned int node_pos = 0;
        node_pos = list_create_new(new_list, file_line[num], num_of_territories);
        //printf("Created another sublist for char %c at pos %d\n", file_line[num], node_pos);
        new_list->lists[node_pos].array_size++; /* move it onto 0 from -1 */
        new_list->lists[node_pos].file_num[new_list->lists[node_pos].array_size++] = num;
        char_array[node_pos] = file_line[num];
        char_array_pos_filled[node_pos] =true;
      }

    }
  }
}






/*****************************************************************************
* return_country_number
*
* This routine returns the country code number of a passed in country.
*
* Assumptions
*  That the version of the International module has knowledge about the
*   country that is being requested.
*
* Inputs
*  country     : A string containing the name of the territory to be
*                 converted.
*
* Outputs
*  None
*
* Returns
*  This routine returns the numeric form of the territory name passed in, or
*   -1 if it is not a valid country. Note that build machines that wish
*   to use utilities that inclue this routine should ensure that they have
*   the latest version of the International module so that they can ensure
*   they are aware of all the latest Name->number mappings.
*
*****************************************************************************/
int return_country_number(const char* const country)
{
  _kernel_swi_regs reg;
  int return_value = 0;

  reg.r[1] = Service_International;
  reg.r[2] = 0;              /* sub-reason code 0 */
  reg.r[3] = (int)country;   /* The country we require (NULL terminated) */
  reg.r[4] = 0;
  _kernel_swi(OS_ServiceCall, &reg, &reg);

  if (reg.r[1] != 0)
    return_value = -1; /* Unrecognised country */
  else
    return_value = reg.r[4];

  return (return_value);
}




/* Things to do:
   3) Implement a system where all the files in all the resource directories
are listed. Use this list to search for the files, and not scanning through
one individual directory. Currently if a file is not present in the main
resource directory being scanned but is present in one of the other resource
directories, then it will not be scanned.
   4) As part of 3) above, ensure that if a file is not present the system
still works.

Completed ones:
   9) Make it use ServiceCall_Territory 0 insetad of Territory_NameToNumber
   2) A common case is for all files to be identical; catch the case where
all bytes in a line of the file are identical early and drop out without
doing the laborious list calculations.
   10) Convert the char array that is read from the file to integers. This
will allow filetypes and filesizes to be compared, as well as the actual file
contents.
   8) Get the filesize and filetype things working.
   7) Test with 1,2,3,4 and 5 territories set.
   5) Ensure that the created resource directories are in the processed
directory, not the resources one as they are at present. Do this by altering
the command-line arguments so that the required processed directory is passed
in as a flag.
   1) Cope with squash files.
   6) If there is only one territory, none of the above should happen, and
the resources should be copied straight into the relevant territory
directory.  
  11) There should always be a 'common' directory, called 'Common'. In the
case of single-territory builds, this will be the territory itself. In the
case of multiple territory builds, this will be the 'common' directory (e.g.
0107 for UK and German builds).
  12) If the locale_list does not include UK, make the first locale in the
list also map to territory 01. This prevents problems with the UK resource
set being expected in ROM by making the Kernel believe that the first
resource set is the UK set, even if it is not.
  13) Ensure that if there is only one territory it copies the resources
directory over to te processed directory, meaning that the scanning does not
have to be done and saving time.
 */



/*****************************************************************************
* END OF FILE
*****************************************************************************/


