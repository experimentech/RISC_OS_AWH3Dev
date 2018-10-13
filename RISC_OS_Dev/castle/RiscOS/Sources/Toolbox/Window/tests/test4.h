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
#define RadioFlags 0
#define RadioGadgetType  4
#define RadioType  RadioButton

#define ACTION_BUTTON_TEXT "ActBut          "
#define ACTION_BUTTON_TEXTLEN (sizeof ACTION_BUTTON_TEXT + 1)

#define OPTION_BUTTON_TEXT "OptBut          "
#define OPTION_BUTTON_TEXTLEN (sizeof OPTION_BUTTON_TEXT + 1)

#define LABELLED_BOX_TEXT "Labelled box"

#define LABEL_TEXT "Label"

#define RADIO_BUTTON_TEXT  "Radio           "
#define RADIO_BUTTON_TEXTLEN (sizeof RADIO_BUTTON_TEXT + 1)

#define DISPLAY_FIELD_TEXT "Display         "
#define DISPLAY_FIELD_TEXTLEN (sizeof DISPLAY_FIELD_TEXT + 1)

#define WRITABLE_FIELD_TEXT "Writable       "
#define WRITABLE_FIELD_TEXTLEN (sizeof WRITABLE_FIELD_TEXT + 1)
#define WRITABLE_FIELD_ALLOWABLE "a"

#define MAX_TEST_GADGETS 37

static Gadget gadgets[] = {
  {
    0,
    2,
    sizeof (GadgetHeader) + sizeof (LabelledBox),
    28, -729, 868, -1,
    0,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    1, /* Sprite */
    2,
    sizeof (GadgetHeader) + sizeof (LabelledBox),
    588, -332, 840, -46,
    2,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    Label_NoBox | Label_RightJustify,
    3,
    sizeof (GadgetHeader) + sizeof (Label),
    66, -206, 168, -162,
    4,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    224, -458, 366, -414,
    5,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    0,
    5,
    sizeof (GadgetHeader) + sizeof (DisplayField),
    168, -210, 560, -158,
    6,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    224, -514, 366, -470,
    7,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    0,
    1,
    sizeof (GadgetHeader) + sizeof (OptionButton),
    616, -206, 794, -162,
    8,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    224, -570, 366, -526,
    9,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    Label_NoBox | Label_RightJustify,
    3,
    sizeof (GadgetHeader) + sizeof (Label),
    66, -262, 168, -218,
    10,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    224, -626, 366, -582,
    11,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    56, -402, 198, -358,
    12,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    224, -682, 366, -638,
    13,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    0,
    5,
    sizeof (GadgetHeader) + sizeof (DisplayField),
    168, -322, 560, -270,
    14,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    392, -402, 534, -358,
    15,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    56, -458, 198, -414,
    16,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    392, -458, 534, -414,
    17,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    Label_NoBox | Label_RightJustify,
    3,
    sizeof (GadgetHeader) + sizeof (Label),
    66, -150, 168, -106,
    18,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    392, -514, 534, -470,
    19,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    56, -514, 198, -470,
    20,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    392, -570, 534, -526,
    21,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    0,
    5,
    sizeof (GadgetHeader) + sizeof (DisplayField),
    168, -154, 560, -102,
    22,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    392, -626, 534, -582,
    23,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    56, -570, 198, -526,
    24,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    392, -682, 534, -638,
    25,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    Label_NoBox | Label_RightJustify,
    3,
    sizeof (GadgetHeader) + sizeof (Label),
    66, -318, 168, -274,
    26,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    560, -402, 702, -358,
    27,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    56, -626, 198, -582,
    28,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    560, -458, 702, -414,
    29,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    Label_NoBox | Label_RightJustify,
    3,
    sizeof (GadgetHeader) + sizeof (Label),
    66, -94, 168, -50,
    30,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    560, -514, 702, -470,
    31,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    56, -682, 198, -638,
    32,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    560, -570, 702, -526,
    33,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    0,
    5,
    sizeof (GadgetHeader) + sizeof (DisplayField),
    168, -98, 560, -46,
    34,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    560, -626, 702, -582,
    35,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    224, -402, 366, -358,
    36,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    RadioFlags,
    RadioGadgetType,
    sizeof (GadgetHeader) + sizeof (RadioType),
    560, -682, 702, -638,
    37,
    "Thing",
    sizeof "Thing" + 1
  },
  {
    0,
    5,
    sizeof (GadgetHeader) + sizeof (DisplayField),
    168, -266, 560, -214,
    38,
    "Thing",
    sizeof "Thing" + 1
  }
} ;
