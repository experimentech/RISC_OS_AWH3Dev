LLKS    SETA    0
LLK     SETS    "DCB"
KeyStructPC26
        &       KeyTranPC26-KeyStructPC26
        &       ((KeyTranPC26End-KeyTranPC26) :SHR: (LLKS+2))
        &       InkeyTranPC-KeyStructPC26
        &       ShiftingKeyList-KeyStructPC26
        &       SpecialListPC26-KeyStructPC26
        &       SpecialCodeTable-KeyStructPC26
        &       KeyStructInit-KeyStructPC26
        &       PendingAltCode-KeyStructPC26
        &       &00000000
        &       PadKNumTran-KeyStructPC26-((SpecialListPC26Pad-SpecialListPC26):SHR:LLKS)
        &       PadKCurTran-KeyStructPC26-((SpecialListPC26Pad-SpecialListPC26):SHR:LLKS)
        &       0
        &       UCSTablePC26_0-KeyStructPC26-((SpecialListPC26UCS-SpecialListPC26):SHR:LLKS)*36
        &       UCSTablePC26_0-KeyStructPC26-((SpecialListPC26UCS-SpecialListPC26):SHR:LLKS)*36

KeyTranPC26
        $LLK    &1B, &1B, &1B, &1B
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &83, &93, &A3, &B3
        $LLK    &84, &94, &A4, &B4
        $LLK    &85, &95, &A5, &B5
        $LLK    &86, &96, &A6, &B6
        $LLK    &87, &97, &A7, &B7
        $LLK    &88, &98, &A8, &B8
        $LLK    &89, &99, &A9, &B9
        $LLK    &CA, &DA, &EA, &FA
        $LLK    &CB, &DB, &EB, &FB
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &80, &90, &A0, &B0
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &34, &24, &04, &04
        $LLK    &35, &25, &05, &05
        $LLK    &36, &5E, &1E, &1E
        $LLK    &37, &26, &07, &07
        $LLK    &38, &2A, &08, &08
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &3D, &2B, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &08, &08, &08, &08
        $LLK    &CD, &DD, &ED, &FD
        $LLK    &1E, &1E, &1E, &1E
        $LLK    &9F, &8F, &BF, &AF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &5B, &7B, &1B, &1B
        $LLK    &5D, &7D, &1D, &1D
        $LLK    &5C, &7C, &1C, &1C
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &8B, &9B, &AB, &BB
        $LLK    &9E, &8E, &BE, &AE
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &2C, &22, &FF, &FF
        $LLK    &0D, &0D, &0D, &0D
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &2E, &3F, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &8F, &9F, &AF, &BF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &8C, &9C, &AC, &BC
        $LLK    &8E, &9E, &AE, &BE
        $LLK    &8D, &9D, &AD, &BD
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &FF, &FF, &FF, &FF
        $LLK    &C0, &D0, &E0, &F0
        $LLK    &D0, &C0, &F0, &E0
        $LLK    &C1, &D1, &E1, &F1
KeyTranPC26End


SpecialListPC26
        $LLK    ((SpecialListPC26End - SpecialListPC26) :SHR: LLKS) - 1
        $LLK    KeyNo_ShiftLeft
        $LLK    KeyNo_ShiftRight
        $LLK    KeyNo_CtrlLeft
        $LLK    KeyNo_CtrlRight
        $LLK    KeyNo_AltLeft
        $LLK    KeyNo_AltRight
        $LLK    KeyNo_FN
        $LLK    KeyNo_LeftMouse
        $LLK    KeyNo_CentreMouse
        $LLK    KeyNo_RightMouse
        $LLK    KeyNo_Break
SpecialListPC26Pad
        $LLK    KeyNo_NumPadSlash, KeyNo_NumPadStar, KeyNo_NumPadHash
        $LLK    KeyNo_NumPad7, KeyNo_NumPad8, KeyNo_NumPad9, KeyNo_NumPadMinus
        $LLK    KeyNo_NumPad4, KeyNo_NumPad5, KeyNo_NumPad6, KeyNo_NumPadPlus
        $LLK    KeyNo_NumPad1, KeyNo_NumPad2, KeyNo_NumPad3
        $LLK    KeyNo_NumPad0, KeyNo_NumPadDot, KeyNo_NumPadEnter
        $LLK    KeyNo_ScrollLock
        $LLK    KeyNo_NumLock
        $LLK    KeyNo_Tab
        $LLK    KeyNo_CapsLock
SpecialListPC26UCS
        $LLK    &01, &02, &0C, &10, &11, &12, &13, &19
        $LLK    &1A, &1B, &1D, &27, &28, &29, &2A, &2B
        $LLK    &2C, &2D, &2E, &2F, &30, &34, &3C, &3D
        $LLK    &3E, &3F, &40, &41, &42, &43, &44, &45
        $LLK    &4E, &4F, &50, &51, &52, &53, &54, &55
        $LLK    &56, &5F
SpecialListPC26End
        ALIGN
        ASSERT ((SpecialListPC26End-SpecialListPC26):SHR:LLKS)-1 <= (SpecialCodeTableEnd-SpecialCodeTable):SHR:2

UCSTablePC26_0
        &       &80000081,&80000091,&800000A1,&800000B1 ; &01
        &       &FFFFFFFF,&FFFFFFFF,&80010006,&FFFFFFFF, &76543210
        &       &80000082,&80000092,&800000A2,&800000B2 ; &02
        &       &FFFFFFFF,&FFFFFFFF,&80010007,&FFFFFFFF, &76543210
        &       &800000CC,&800000DC,&800000EC,&800000FC ; &0C
        &       &FFFFFFFF,&FFFFFFFF,&80010008,&FFFFFFFF, &76543210
        &       &00000060,&0000007E,&FFFFFFFF,&FFFFFFFF ; &10
        &       &000000AC,&000000B0,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000031,&00000021,&00000001,&00000001 ; &11
        &       &000000B9,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000032,&00000040,&00000000,&00000000 ; &12
        &       &000000B2,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000033,&00000023,&00000003,&00000003 ; &13
        &       &000000B3,&000000A3,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000039,&00000028,&00000009,&00000009 ; &19
        &       &FFFFFFFF,&000000B1,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000030,&00000029,&00000000,&00000000 ; &1A
        &       &000000B0,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002D,&0000005F,&0000001F,&0000001F ; &1B
        &       &000000AD,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000000A3,&000000A4,&FFFFFFFF,&FFFFFFFF ; &1D
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &0000002F,&00000051,&00000011,&00000011 ; &27
        &       &00000071,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &00000027,&00000057,&00000017,&00000017 ; &28
        &       &00000077,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005E7,&00000045,&00000005,&00000005 ; &29
        &       &00000065,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005E8,&00000052,&00000012,&00000012 ; &2A
        &       &00000072,&000000AE,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005D0,&00000054,&00000014,&00000014 ; &2B
        &       &00000074,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005D8,&00000059,&00000019,&00000019 ; &2C
        &       &00000079,&000000A5,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005D5,&00000055,&00000015,&00000015 ; &2D
        &       &00000075,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005DF,&00000049,&00000009,&00000009 ; &2E
        &       &00000069,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005DD,&0000004F,&0000000F,&0000000F ; &2F
        &       &0000006F,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005E4,&00000050,&00000010,&00000010 ; &30
        &       &00000070,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &80010009,&80010009,&80010009,&80010009 ; &34
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000005E9,&00000041,&00000001,&00000001 ; &3C
        &       &00000061,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005D3,&00000053,&00000013,&00000013 ; &3D
        &       &00000073,&000000A7,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005D2,&00000044,&00000004,&00000004 ; &3E
        &       &00000064,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005DB,&00000046,&00000006,&00000006 ; &3F
        &       &00000066,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005E2,&00000047,&00000007,&00000007 ; &40
        &       &00000067,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005D9,&00000048,&00000008,&00000008 ; &41
        &       &00000068,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005D7,&0000004A,&0000000A,&0000000A ; &42
        &       &0000006A,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005DC,&0000004B,&0000000B,&0000000B ; &43
        &       &0000006B,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005DA,&0000004C,&0000000C,&0000000C ; &44
        &       &0000006C,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005E3,&000005E3,&FFFFFFFF,&FFFFFFFF ; &45
        &       &FFFFFFFF,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000005D6,&0000005A,&0000001A,&0000001A ; &4E
        &       &0000007A,&000000AB,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005E1,&00000058,&00000018,&00000018 ; &4F
        &       &00000078,&000000BB,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005D1,&00000043,&00000003,&00000003 ; &50
        &       &00000063,&000000A2,&000000A9,&FFFFFFFF, &765132C0
        &       &000005D4,&00000056,&00000016,&00000016 ; &51
        &       &00000076,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005E0,&00000042,&00000002,&00000002 ; &52
        &       &00000062,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005DE,&0000004E,&0000000E,&0000000E ; &53
        &       &0000006E,&FFFFFFFF,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005E6,&0000004D,&0000000D,&0000000D ; &54
        &       &0000006D,&000000B5,&FFFFFFFF,&FFFFFFFF, &765132C0
        &       &000005EA,&0000003C,&FFFFFFFF,&FFFFFFFF ; &55
        &       &FFFFFFFF,&000000D7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &000005E5,&0000003E,&FFFFFFFF,&FFFFFFFF ; &56
        &       &FFFFFFFF,&000000F7,&FFFFFFFF,&FFFFFFFF, &76543210
        &       &00000020,&00000020,&00000020,&00000020 ; &5F
        &       &000000A0,&000000A0,&FFFFFFFF,&FFFFFFFF, &76543210

        ALIGN

        END
