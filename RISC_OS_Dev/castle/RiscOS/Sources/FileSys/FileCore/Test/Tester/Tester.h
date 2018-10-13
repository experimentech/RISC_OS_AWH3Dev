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
extern void pout_error( _kernel_oserror *err );
extern void check_regs_unchanged( _kernel_swi_regs *oldr, _kernel_swi_regs *newr, int mask );
extern void check_catalogue_info( char *name, int type, int load, int exec, unsigned int length, int attributes, int mask );
extern void big_file_test( char *name );
extern int myrand( void );
extern char *random_filename( void );
extern int random_attributes( void );
extern char *random_attribs( void );
extern char *random_directory( void );
extern char *random_file( void );
extern char *random_object( void );
extern char *new_random_path( void );

#define Yes               1
#define No                0
#define BigFiles          Yes
#define NumberOfOpenFiles 20
#define RandomDataAmount  50000
typedef struct OpenFile
{
        int file;
        char *name;
}       OpenFile;
extern OpenFile open_files[ NumberOfOpenFiles ];

extern OpenFile *random_open( void );
extern void close_open( OpenFile *f );
extern int *random_closed( void );
extern void ensure_closed( char *name );
extern int *random_open_file( void );
extern char *random_closed_file( void );
extern char *random_closed_object( void );
extern int problems;
extern char **path_roots;
extern int number_of_paths;
extern int nest_probability;
extern char random_data_area[ RandomDataAmount ];
extern char random_write_result[ RandomDataAmount ];
extern void os_file0( char *name, int load, int exec, unsigned int length );
extern void os_file1( char *name, int load, int exec, int attributes );
extern void os_file2( char *name, int load );
extern void os_file3( char *name, int exec );
extern void os_file4( char *name, int attributes );
extern void os_file6( char *name );
extern void os_file7( char *name, int load, int exec, unsigned int start, unsigned int end );
extern void os_file8( char *name, int ents );
extern void os_file9( char *name );
extern void os_file10( char *name, int type, unsigned int length );
extern void os_file11( char *name, int type, unsigned int start, unsigned int end );
extern void os_file16( char *name );
extern void os_file17( char *name );
extern void os_file18( char *name, int type );
extern void os_args0( int *file );
extern void os_args1( int *file, unsigned int pointer );
extern void os_args2( int *file );
extern void os_args3( int *file, unsigned int extent );
extern void os_args4( int *file );
extern void os_args5( int *file );
extern void os_args6( int *file, unsigned int ensure );
extern void os_args255( int *file );
extern void os_bget( int *file );
extern void os_bput( int *file, char byte );
extern void os_gbpb1( int *file, unsigned int size, unsigned int location );
extern void os_gbpb2( int *file, unsigned int size );
extern void os_gbpb3( int *file, unsigned int size, unsigned int location );
extern void os_gbpb4( int *file, unsigned int size );
extern void os_gbpb5( void );
extern void os_gbpb6( void );
extern void os_gbpb7( void );
extern void os_gbpb8( int number );
extern void os_gbpb9( char *name, int number );
extern void os_gbpb10( char *name, int number );
extern void os_gbpb11( char *name, int number );
extern void os_findclose( int *file );
extern void os_findin( char *file );
extern void os_findout( char *file );
extern void os_findup( char *file );
extern void os_fscontrol0( char *name );
extern void os_fscontrol1( char *name );
extern void os_fscontrol5( char *name );
extern void os_fscontrol6( char *name );
extern void os_fscontrol7( void );
extern void os_fscontrol8( void );
extern void os_fscontrol9( char *file );
extern void os_fscontrol24( char *file, char *opts );
extern void os_fscontrol25( char *from, char *to );
extern void os_fscontrol32( char *file );
#define FileError_Mask                  0xff00ff
#define Error_AccessViolation           0xbd
#define Error_FSAccessViolation         0x0100bd
#define Error_NotOpenForUpdate          0xc1
#define Error_OutsideFile               0xb7
#define Error_Locked                    0x100c3
#define Error_FSLocked                  0xc3
#define Error_TypesDontMatch            0x100c5
#define Error_DirNotEmpty               0x100b4
#define Error_EndOfFile                 0xdf
#define Error_CantDeleteCurrent         0x10096
#define Error_CantDeleteLibrary         0x10097
#define Error_NotSameDisc               0x1009f
#define Error_DoesNotExist              0x0100d6
#define Error_FSDoesNotExist            0xd6
#define Error_NotOpenForReading         0x413
#define ErrorNumber_NFS_directory_unset 0x012114
#define Error_NotFound                  0xd6
#define Error_BadRENAME                 0x0100b0
#define Error_DirectoryFull             0x0100b3
#define Error_FileOpen                  0x0100c2
#define Error_Full                      0x0100c6
