#include <os/log.h>

#include <DriverKit/IOLib.h>
#include <USBDriverKit/IOUSBHostDevice.h>

#include "Mbox2Driver.h"

kern_return_t
IMPL(Mbox2Driver, Start)
{
    kern_return_t result = Start(provider, SUPERDISPATCH);

    if (result != KERN_SUCCESS) {
        os_log(OS_LOG_DEFAULT,
               "Mbox2Driver: superclass Start failed: 0x%x",
               result);
        return result;
    }

    _usbDevice = nullptr;

    IOUSBHostDevice * device =
        (IOUSBHostDevice *)provider;

    if (device == nullptr) {
        os_log(OS_LOG_DEFAULT,
               "Mbox2Driver: USB device provider is missing");
        return kIOReturnBadArgument;
    }

    result = device->Open(this, 0, 0);

    if (result != KERN_SUCCESS) {
        os_log(OS_LOG_DEFAULT,
               "Mbox2Driver: USB device open failed: 0x%x",
               result);
        return result;
    }

    _usbDevice = provider;

    const IOUSBDeviceDescriptor * descriptor =
        device->CopyDeviceDescriptor();

    if (descriptor == nullptr) {
        os_log(OS_LOG_DEFAULT,
               "Mbox2Driver: Could not read USB device descriptor");
        device->Close(this, 0);
        _usbDevice = nullptr;
        return kIOReturnError;
    }

    os_log(OS_LOG_DEFAULT,
           "Mbox2Driver: USB device opened - VID 0x%04x PID 0x%04x",
           descriptor->idVendor,
           descriptor->idProduct);

    os_log(OS_LOG_DEFAULT,
           "Mbox2Driver: USB device revision 0x%04x",
           descriptor->bcdDevice);

    IOFree((void *)descriptor, sizeof(IOUSBDeviceDescriptor));

    os_log(OS_LOG_DEFAULT,
           "Mbox2Driver: USB foundation started successfully");

    return KERN_SUCCESS;
}

void
IMPL(Mbox2Driver, Stop)
{
    if (_usbDevice != nullptr) {
        IOUSBHostDevice * device =
            (IOUSBHostDevice *)_usbDevice;

        device->Close(this, 0);
        _usbDevice = nullptr;
    }

    Stop(provider, SUPERDISPATCH);
}
