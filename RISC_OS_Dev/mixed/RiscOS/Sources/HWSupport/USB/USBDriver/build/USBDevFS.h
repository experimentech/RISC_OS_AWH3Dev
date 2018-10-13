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
* Purpose:  Data structures pertinent to the DeviceFS USB interface for
*           RISC OS. Authors should consult the other documentation for a
*           full explanation of the terms used, as this header file is
*           not primarly intended to document the API.
*
*           Note that these data structures are ARM architecture dependant,
*           ie. 32-bit little endian
*****************************************************************************/

#ifndef __USBDevFS
#define __USBDevFS

/*****************************************************************************
* Macros defining types for the compiler
*****************************************************************************/

#ifndef __stdint_h
#ifndef uint8_t
 #define uint8_t unsigned char
#endif
#ifndef int8_t
 #define int8_t  signed char
#endif
#ifndef uint16_t
 #define uint16_t unsigned short
#endif
#ifndef int16_t
 #define int16_t signed short
#endif
#ifndef uint32_t
 #define uint32_t unsigned int
#endif
#ifndef int32_t
 #define int32_t signed int
#endif
#endif

/*****************************************************************************
* Service call definitions issued when USB system events occur
*****************************************************************************/

#ifndef Service_USB
#define Service_USB                         0xD2
#endif
#define Service_USB_Attach                  0x00
        /* Used to report the addition of a new USB device to the system
           On entry: R0 =  0x00
                     R1 =  0xD2
                     R2 -> USBServiceCall block as defined below
           On exit:  Do not claim this call, it is for information only */
#define Service_USB_Connected               0x01
        /* Issued with OS_ServiceCall by any application or module which
           wishes to get information on all of the currently connected
           devices without needing to keep track of Attach and Detach
           On entry: R0 =  0x01
                     R1 =  0xD2
           On exit:  R2 -> Linked list of USBServiceCall blocks as defined below
                     Do not claim this call, other USB drivers in the module chain
                     may wish to add further blocks to the list */
#define Service_USB_Detach                  0x02
        /* Unused
           When a device detaches, DeviceFS will report it with a
           Service_DeviceDead message */
#define Service_USB_USBDriverStarting       0x03
        /* Used to notify the (re)starting of the USB system and for any
           clients of USBDriver to (re)register themselves
           On entry: R0 =  0x03
                     R1 =  0xD2
           On exit:  Do not claim this call, it is for information only */
#define Service_USB_USBDriverDying          0x04
        /* Used to notify that the USB system is shutting down
           On entry: R0 =  0x04
                     R1 =  0xD2
           On exit:  Do not claim this call, it is for information only */
#define Service_USB_USBDriverDead           0x05
        /* Used to notify that the USB system has shut down
           On entry: R0 =  0x05
                     R1 =  0xD2
           On exit:  Do not claim this call, it is for information only */

#ifndef _USB_H_ /* Avoid conflicts if NetBSD USB headers included */
/*****************************************************************************
* USB descriptor types as C structures
*****************************************************************************/

#define  UDESC_DEVICE           0x01
#define  UDESC_CONFIG           0x02
#define  UDESC_STRING           0x03
#define  UDESC_INTERFACE        0x04
#define  UDESC_ENDPOINT         0x05
/* 0x06  Reserved for high speed device qualifers
   0x07  Reserved for 'other' speed configuration info, layout per UDESC_CONFIG
   0x08  Reserved for interface power info
   Other Reserved */
#define  UDESC_OTG              0x09
#define  UDESC_CS_DEVICE        0x21 /* class specific */
#define  UDESC_CS_CONFIG        0x22
#define  UDESC_CS_STRING        0x23
#define  UDESC_CS_INTERFACE     0x24
#define  UDESC_CS_ENDPOINT      0x25
#define  UDESC_HUB              0x29

/* Device (descriptor type 0x01) */
typedef __packed struct {
        uint8_t         bLength;
        uint8_t         bDescriptorType;
        uint16_t        bcdUSB;
        uint8_t         bDeviceClass;
        uint8_t         bDeviceSubClass;
        uint8_t         bDeviceProtocol;
        uint8_t         bMaxPacketSize;
        uint16_t        idVendor;
        uint16_t        idProduct;
        uint16_t        bcdDevice;
        uint8_t         iManufacturer;
        uint8_t         iProduct;
        uint8_t         iSerialNumber;
        uint8_t         bNumConfigurations;
} usb_device_descriptor_t;
#define USB_DEVICE_DESCRIPTOR_SIZE 18

/* Configuration (descriptor type 0x02) */
typedef __packed struct {
        uint8_t         bLength;
        uint8_t         bDescriptorType;
        uint16_t        wTotalLength;
        uint8_t         bNumInterface;
        uint8_t         bConfigurationValue;
        uint8_t         iConfiguration;
        uint8_t         bmAttributes;
        uint8_t         bMaxPower; /* max current in 2 mA units */
} usb_config_descriptor_t;
#define USB_CONFIG_DESCRIPTOR_SIZE 9

/* String (descriptor type 0x03) */
typedef __packed struct {
        uint8_t         bLength;
        uint8_t         bDescriptorType;
        uint16_t        bString[127];
} usb_string_descriptor_t;
#define USB_MAX_STRING_LEN 128

/* Interface (descriptor type 0x04) */
typedef __packed struct {
        uint8_t         bLength;
        uint8_t         bDescriptorType;
        uint8_t         bInterfaceNumber;
        uint8_t         bAlternateSetting;
        uint8_t         bNumEndpoints;
        uint8_t         bInterfaceClass;
        uint8_t         bInterfaceSubClass;
        uint8_t         bInterfaceProtocol;
        uint8_t         iInterface;
} usb_interface_descriptor_t;
#define USB_INTERFACE_DESCRIPTOR_SIZE 9

/* Endpoint (descriptor type 0x05) */
typedef __packed struct {
        uint8_t         bLength;
        uint8_t         bDescriptorType;
        uint8_t         bEndpointAddress;
        uint8_t         bmAttributes;
        uint16_t        wMaxPacketSize;
        uint8_t         bInterval;
} usb_endpoint_descriptor_t;
#define USB_ENDPOINT_DESCRIPTOR_SIZE 7

/* Hub (descriptor type 0x29) */
typedef __packed struct {
        uint8_t         bDescLength;
        uint8_t         bDescriptorType;
        uint8_t         bNbrPorts;
        uint16_t        wHubCharacteristics;
        uint8_t         bPwrOn2PwrGood; /* delay in 2 ms units */
        uint8_t         bHubContrCurrent;
        uint8_t         DeviceRemovable[32]; /* max 255 ports */
        uint8_t         PortPowerCtrlMask[1]; /* deprecated */
} usb_hub_descriptor_t;
#define USB_HUB_DESCRIPTOR_SIZE 9

/* The following struct allows you to cast then extract the length and type */
typedef __packed struct {
        uint8_t         bLength;
        uint8_t         bDescriptorType;
        uint8_t         bDescriptorSubtype; /* optional */
} usb_descriptor_t;
#endif /* _USB_H_ */

/*****************************************************************************
* Service call format as a C structure
*****************************************************************************/

/* A USB device is completely described by the block (or list of blocks)
   pointed to by R2 in the USB service calls defined above
   The USBServiceCall includes a copy of the device descriptor, followed
   immediately by zero or more descriptors. A length byte of zero marks the
   end of the block, which is then padded with zeros to achieve word
   alignment */

typedef struct USBServiceCall {
uint16_t                sclen;       // sum length of the block including
                                     // the appended descriptors
uint16_t                descoff;     // offset to the descriptors
char                    devname[20]; // device name as appears in DeviceFS
                                     // e.g.USB37  NULL terminated
uint8_t                 bus;         // bus number, 0-255
uint8_t                 devaddr;     // usb address,1-127
uint8_t                 hostaddr;    // usb address of upstream port 0-127
uint8_t                 hostport;    // port on host address
uint8_t                 speed;       // device speed
                                     // 1:     low speed (1.5Mbps)
                                     // 2:     full speed (12Mbps)
                                     // 3:     hi speed (480Mbps)
                                     // others:reserved
                                     // Note: Old versions of USBDriver
                                     // (version < 0.27 with date <= 07 Jan
                                     // 2004) used a different scheme:
                                     // 0:     low speed (1.5Mbps)
                                     // 1:     full speed (12Mbps)
uint8_t                 spare1;      // spare, set NULL
uint8_t                 spare2;      // spare, set NULL
uint8_t                 spare3;      // spare, set NULL
usb_device_descriptor_t ddesc;       // device descriptor
                                     // followed immediately by zero or more
                                     // descriptors (with no word alignment
                                     // gaps)
} USBServiceCall;

typedef struct USBServiceAnswer USBServiceAnswer;
struct USBServiceAnswer {
USBServiceAnswer     * link;         // pointer to next, or NULL for no more
USBServiceCall         svc;          // data as per 'Attach' service call
};

/*****************************************************************************
* DeviceFS_CallDevice codes
*****************************************************************************/

#define DeviceCall_USB_USBRequest       0x80000000
#define DeviceCall_USB_BufferSpace      0x80000002
#define DeviceCall_USB_GetHandles       0x80000003
#define DeviceCall_USB_GetLocation      0x80000004
#define DeviceCall_USB_ClearStall       0x80000005
#define DeviceCall_USB_TransferInfo     0x80000006
#define DeviceCall_USB_GetHandles2      0x80000007
#define DeviceCall_USB_GetSetOptions    0x80000008

#endif  /* end of sentry #ifdef */
/*****************************************************************************
* END OF FILE
*****************************************************************************/
