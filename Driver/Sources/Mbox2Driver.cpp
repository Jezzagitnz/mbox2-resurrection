#include <os/log.h>

#include <DriverKit/IOUserServer.h>
#include <DriverKit/IOLib.h>
#include <DriverKit/Mbox2Driver.h>

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

    os_log(OS_LOG_DEFAULT,
           "Mbox2Driver: DriverKit service started");

    return KERN_SUCCESS;
}

#include <DriverKit/Mbox2Driver.iig.cpp>
