#import "Mbox2Control-Bridging-Header.h"
#import <IOKit/IOCFPlugIn.h>

int32_t Mbox2CreateUSBInterface(
    io_service_t service,
    CFStringRef userClientUUID,
    CFStringRef interfaceUUID,
    void **outInterface
) {
    if (outInterface == NULL) {
        return kIOReturnBadArgument;
    }

    *outInterface = NULL;

    CFUUIDRef userClientType =
        CFUUIDCreateFromString(kCFAllocatorDefault, userClientUUID);

    CFUUIDRef requestedInterface =
        CFUUIDCreateFromString(kCFAllocatorDefault, interfaceUUID);

    CFUUIDRef pluginType = CFUUIDCreateFromString(
        kCFAllocatorDefault,
        CFSTR("C244E858-109C-11D4-91D4-0050E4C6426F")
    );

    if (userClientType == NULL ||
        requestedInterface == NULL ||
        pluginType == NULL) {

        if (userClientType) CFRelease(userClientType);
        if (requestedInterface) CFRelease(requestedInterface);
        if (pluginType) CFRelease(pluginType);

        return kIOReturnError;
    }

    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;

    IOReturn pluginResult = IOCreatePlugInInterfaceForService(
        service,
        userClientType,
        pluginType,
        &plugin,
        &score
    );

    CFRelease(userClientType);
    CFRelease(pluginType);

    if (pluginResult != kIOReturnSuccess || plugin == NULL) {
        CFRelease(requestedInterface);
        return pluginResult;
    }

    HRESULT queryResult = (*plugin)->QueryInterface(
        plugin,
        CFUUIDGetUUIDBytes(requestedInterface),
        outInterface
    );

    IODestroyPlugInInterface(plugin);
    CFRelease(requestedInterface);

    return (int32_t)queryResult;
}

int32_t Mbox2CreateInterfaceIterator(
    void *deviceInterface,
    io_iterator_t *outIterator
) {
    if (deviceInterface == NULL || outIterator == NULL) {
        return kIOReturnBadArgument;
    }

    *outIterator = 0;

    IOUSBDeviceInterface100 **device =
        (IOUSBDeviceInterface100 **)deviceInterface;

    IOUSBFindInterfaceRequest request = {
        0xFFFF,
        0xFFFF,
        0xFFFF,
        0xFFFF
    };

    return (int32_t)(*device)->CreateInterfaceIterator(
        device,
        &request,
        outIterator
    );
}

int32_t Mbox2OpenUSBInterface(void *interfacePointer) {
    if (interfacePointer == NULL) {
        return kIOReturnBadArgument;
    }

    IOUSBInterfaceInterface500 **interface =
        (IOUSBInterfaceInterface500 **)interfacePointer;

    return (int32_t)(*interface)->USBInterfaceOpen(interface);
}

int32_t Mbox2CloseUSBInterface(void *interfacePointer) {
    if (interfacePointer == NULL) {
        return kIOReturnBadArgument;
    }

    IOUSBInterfaceInterface500 **interface =
        (IOUSBInterfaceInterface500 **)interfacePointer;

    return (int32_t)(*interface)->USBInterfaceClose(interface);
}

int32_t Mbox2ReleaseUSBDeviceInterface(void *deviceInterface) {
    if (deviceInterface == NULL) {
        return kIOReturnBadArgument;
    }

    IOUSBDeviceInterface100 **device =
        (IOUSBDeviceInterface100 **)deviceInterface;

    return (int32_t)(*device)->Release(device);
}

int32_t Mbox2ReleaseUSBInterface(void *interfacePointer) {
    if (interfacePointer == NULL) {
        return kIOReturnBadArgument;
    }

    IOUSBInterfaceInterface500 **interface =
        (IOUSBInterfaceInterface500 **)interfacePointer;

    return (int32_t)(*interface)->Release(interface);
}
