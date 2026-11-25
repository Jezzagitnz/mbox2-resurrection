import Foundation
import IOKit
import CoreFoundation

struct Mbox2USBInterfaceInfo {
    let vendorID: UInt16
    let productID: UInt16
    let interfaceNumber: UInt16
}

final class Mbox2USBService {

    private let expectedVendorID: UInt16 = 0x0DBA
    private let expectedProductID: UInt16 = 0x3000
    private let expectedInterfaceNumber: UInt16 = 6

    private var usbInterface: UnsafeMutableRawPointer?

    private(set) var isInterface6Initialised = false

    private let deviceUserClientUUID =
        "9DC7B780-9EC0-11D4-A54F-000A27052861"

    private let interfaceUserClientUUID =
        "2D9786C6-9EF3-11D4-AD51-000A27052861"

    private let deviceInterface100UUID =
        "5C8187D0-9EF3-11D4-8B45-000A27052861"

    private let interfaceInterface500UUID =
        "6C0D38C3-B093-4EA7-809B-09FB5DDDAC16"

    func initialiseInterface6() throws -> Mbox2USBInterfaceInfo {
        close()

        guard let matching = IOServiceMatching("IOUSBDevice") else {
            throw serviceError(
                "Could not create USB device matching dictionary."
            )
        }

        var deviceIterator: io_iterator_t = 0

        let matchingResult = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            matching,
            &deviceIterator
        )

        guard matchingResult == KERN_SUCCESS else {
            throw systemError(
                matchingResult,
                description: "Could not search for USB devices."
            )
        }

        defer {
            _ = IOObjectRelease(deviceIterator)
        }

        while true {
            let deviceService = IOIteratorNext(deviceIterator)

            if deviceService == 0 {
                break
            }

            defer {
                _ = IOObjectRelease(deviceService)
            }

            guard
                numberProperty("idVendor", from: deviceService)
                    == expectedVendorID,
                numberProperty("idProduct", from: deviceService)
                    == expectedProductID
            else {
                continue
            }

            try findAndOpenInterface6(on: deviceService)

            return Mbox2USBInterfaceInfo(
                vendorID: expectedVendorID,
                productID: expectedProductID,
                interfaceNumber: expectedInterfaceNumber
            )
        }

        throw serviceError(
            "Digidesign Mbox 2 was not found. Check that it is connected."
        )
    }

    private func findAndOpenInterface6(
        on deviceService: io_service_t
    ) throws {

        var rawDeviceInterface: UnsafeMutableRawPointer?

        let queryResult = Mbox2CreateUSBInterface(
            deviceService,
            deviceUserClientUUID as CFString,
            deviceInterface100UUID as CFString,
            &rawDeviceInterface
        )

        guard queryResult == 0,
              let rawDeviceInterface else {
            throw serviceError(
                "Could not obtain the USB device interface. QueryInterface returned \(queryResult)."
            )
        }

        defer {
            _ = Mbox2ReleaseUSBDeviceInterface(rawDeviceInterface)
        }

        var interfaceIterator: io_iterator_t = 0

        let iteratorResult = Mbox2CreateInterfaceIterator(
            rawDeviceInterface,
            &interfaceIterator
        )

        guard iteratorResult == kIOReturnSuccess else {
            throw systemError(
                iteratorResult,
                description: "Could not enumerate the Mbox 2 interfaces."
            )
        }

        defer {
            _ = IOObjectRelease(interfaceIterator)
        }

        while true {
            let interfaceService = IOIteratorNext(interfaceIterator)

            if interfaceService == 0 {
                break
            }

            defer {
                _ = IOObjectRelease(interfaceService)
            }

            guard numberProperty(
                "bInterfaceNumber",
                from: interfaceService
            ) == expectedInterfaceNumber else {
                continue
            }

            try openInterfaceService(interfaceService)
            return
        }

        throw serviceError(
            "The Mbox 2 was found, but interface 6 was not present."
        )
    }

    private func openInterfaceService(
        _ service: io_service_t
    ) throws {

        var rawInterface: UnsafeMutableRawPointer?

        let queryResult = Mbox2CreateUSBInterface(
            service,
            interfaceUserClientUUID as CFString,
            interfaceInterface500UUID as CFString,
            &rawInterface
        )

        guard queryResult == 0,
              let rawInterface else {
            throw serviceError(
                "Could not obtain IOUSBInterfaceInterface500. QueryInterface returned \(queryResult)."
            )
        }

        let openResult = Mbox2OpenUSBInterface(rawInterface)

        guard openResult == kIOReturnSuccess else {
            _ = Mbox2ReleaseUSBInterface(rawInterface)

            throw systemError(
                openResult,
                description: "IOUSBLib found interface 6 but could not open it. Another system service or application may already own the interface."
            )
        }

        usbInterface = rawInterface
        isInterface6Initialised = true
    }

    func close() {
        guard let usbInterface else {
            isInterface6Initialised = false
            return
        }

        _ = Mbox2CloseUSBInterface(usbInterface)
        _ = Mbox2ReleaseUSBInterface(usbInterface)

        self.usbInterface = nil
        isInterface6Initialised = false
    }

    private func numberProperty(
        _ key: String,
        from service: io_service_t
    ) -> UInt16? {

        guard let property = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else {
            return nil
        }

        return property.uint16Value
    }

    private func systemError(
        _ code: Int32,
        description: String
    ) -> NSError {

        NSError(
            domain: NSMachErrorDomain,
            code: Int(code),
            userInfo: [
                NSLocalizedDescriptionKey:
                    "\(description)\nReturn code: \(code)"
            ]
        )
    }

    private func serviceError(_ description: String) -> NSError {
        NSError(
            domain: "org.mbox2control.usb",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: description
            ]
        )
    }
}
