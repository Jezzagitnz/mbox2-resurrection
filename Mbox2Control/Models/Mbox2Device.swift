import Foundation
import Observation

struct Mbox2Identity {
    let name = "Digidesign Mbox 2"
    let usbVendorID: UInt16 = 0x0DBA
    let usbProductID: UInt16 = 0x3000
}

enum Mbox2ConnectionState: String {
    case notDetected = "Not detected"
    case detected = "Detected"
    case unavailable = "Unavailable"
}

enum Mbox2USBState: String {
    case unknown = "Not checked"
    case interfaceInitialised = "Interface 6 initialised"
    case communicating = "Communicating"
    case notCommunicating = "Not communicating"
}

enum Mbox2DriverState: String {
    case notInstalled = "Not installed"
    case installed = "Installed"
    case inactive = "Inactive"
    case unknown = "Unknown"
}

enum Mbox2SPDIFState: String {
    case unknown = "Unknown"
    case locked = "Locked"
    case unlocked = "Unlocked"
    case unavailable = "Unavailable"
}

enum Mbox2FirmwareState: String {
    case notQueried = "Not queried"
    case available = "Available"
    case unavailable = "Unavailable"
}

enum Mbox2SampleRate: String, CaseIterable {
    case rate44100 = "44.1 kHz"
    case rate48000 = "48 kHz"
}

enum Mbox2BitDepth: String, CaseIterable {
    case bit16 = "16-bit"
    case bit24 = "24-bit"
}

enum Mbox2ClockSource: String, CaseIterable {
    case internalClock = "Internal"
    case spdif = "S/PDIF"
}

@Observable
@MainActor
final class Mbox2Device {

    let identity = Mbox2Identity()
    private let usbService = Mbox2USBService()

    var connectionState: Mbox2ConnectionState = .notDetected

    var usbState: Mbox2USBState = .unknown
    var usbCheckMessage = "USB check has not been run."

    var driverState: Mbox2DriverState = .notInstalled

    var spdifState: Mbox2SPDIFState = .unknown

    var firmwareState: Mbox2FirmwareState = .notQueried
    var firmwareVersion: String?

    var selectedSampleRate: Mbox2SampleRate = .rate44100
    var selectedBitDepth: Mbox2BitDepth = .bit24
    var selectedClockSource: Mbox2ClockSource = .internalClock

    init() {}

    func checkUSBConnection() {
        connectionState = .unavailable
        usbState = .unknown
        usbCheckMessage = "Checking for Mbox 2 interface 6..."

        do {
            _ = try usbService.initialiseInterface6()

            connectionState = .detected
            usbState = .interfaceInitialised
            usbCheckMessage = "Mbox 2 interface 6 was successfully initialised."
        } catch {
            connectionState = .unavailable
            usbState = .notCommunicating
            usbCheckMessage = error.localizedDescription
        }
    }
}
