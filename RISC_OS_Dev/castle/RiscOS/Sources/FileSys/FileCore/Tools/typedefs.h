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
#ifndef FileCore_typedefs
#define FileCore_typedefs

#define bits_per_byte 8
#define bytes_per_word 4
#define bits_per_word (bits_per_byte * bytes_per_word)
#define No (0)
#define Yes (!No)

typedef int YesNoAnswer;

/*
        ADFS structures
*/


typedef struct indirect_disc_address
{
        unsigned int sector_offset:8;
        unsigned int fragment_id:16;
        unsigned int unused:5;
        unsigned int disc_number:3;
}       indirect_disc_address;

typedef struct direct_disc_address
{
        unsigned int byte_offset:29;
        unsigned int disc_number:3;
}       direct_disc_address;

typedef union disc_address
{
        indirect_disc_address indirect;
        direct_disc_address direct;
}       disc_address;

typedef struct zone_header
{
        unsigned int zone_check:8;       /* check byte for this zone map */
        unsigned int free_link:16;       /* bit offset to first free fragment in this zone */
        unsigned int cross_check:8;      /* check byte for all zone maps */
}       zone_header;

typedef struct disc_record
{
        unsigned char log2_sector_size;
        unsigned char sectors_per_track;
        unsigned char heads;
        unsigned char density;
        unsigned char fragment_id_length; /* in map bits */
        unsigned char log2_bytes_per_map_bit;
        unsigned char sector_skew; /* for random access file allocation */
        unsigned char boot_option;
        unsigned char reserved_0;
        unsigned char zones_in_map;
        unsigned short zone_spare; /* bits between last allocation bit in a zone and the
                                        first allocation bit in the next zone */
        disc_address root_directory;
        unsigned int disc_size;
        unsigned short disc_id;
        char disc_name[10];
        unsigned char unused_1[32];
        char bad_block_list[512];
}       disc_record;

typedef struct object_record
{
        struct object_record *next;
        unsigned int id;
        unsigned int size;
        unsigned int fragments;
        indirect_disc_address used_from_directory;
        enum object_status
        {
                unknown,
                unused,
                used_once,
                shared,
                used_many,
                shared_across_directories
        }       status;
        enum object_type
        {
                file,
                directory,
                bad_block,
                root_directory
        }       type;
}       object_record;

#define NameLen         (10)
#define DirTitleSz      (19)

/*
        Directory start header
*/
#define StartMasSeq     (0)
#define StartName       (StartMasSeq+1)
#define DirFirstEntry   ( StartName+4)

/*
        A directory entry (not a structure as needs packing and
        non-word aligning).
*/
#define DirObName       (0)
#define DirLoad         (DirObName+NameLen)
#define DirExec         (DirLoad+4)
#define DirLen          (DirExec+4)
#define DirIndDiscAdd   (DirLen+4)

#define OldDirObSeq     (DirIndDiscAdd+3)

#define NewDirAtts      (DirIndDiscAdd+3)

#define DirEntrySize    (NewDirAtts+1)

#define Atts_ReadBit            (0x01)
#define Atts_WriteBit           (0x02)
#define Atts_LockedBit          (0x04)
#define Atts_DirBit             (0x08)
#define Atts_EBit               (0x10)
#define Atts_PublicReadBit      (0x10)
#define Atts_PublicWriteBit     (0x20)

/*
        A directory end structure
*/
#define DirCheckByte    (-1)
#define EndName         (DirCheckByte-4)
#define EndMasSeq       (EndName-1)

#define OldReserved     (EndMasSeq-14)
#define OldDirTitle     (OldReserved-DirTitleSz)
#define OldDirParent    (OldDirTitle-3)
#define OldDirName      (OldDirParent-NameLen)
#define OldDirLastMark  (OldDirName-1)

#define NewDirName      (EndMasSeq-NameLen)
#define NewDirTitle     (NewDirName-DirTitleSz)
#define NewDirParent    (NewDirTitle-3)
#define NewReserved     (NewDirParent-2)
#define NewDirLastMark  (NewReserved-1)

#define OldDirLen       (0x500)
#define NewDirLen       (0x800)

#endif
