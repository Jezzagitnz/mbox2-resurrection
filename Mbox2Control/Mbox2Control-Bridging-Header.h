#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

int32_t Mbox2CreateUSBInterface(
    io_service_t service,
    CFStringRef userClientUUID,
    CFStringRef interfaceUUID,
    void **outInterface
);

int32_t Mbox2CreateInterfaceIterator(
    void *deviceInterface,
    io_iterator_t *outIterator
);

int32_t Mbox2OpenUSBInterface(void *interfacePointer);
int32_t Mbox2CloseUSBInterface(void *interfacePointer);
int32_t Mbox2ReleaseUSBDeviceInterface(void *deviceInterface);
int32_t Mbox2ReleaseUSBInterface(void *interfacePointer);
