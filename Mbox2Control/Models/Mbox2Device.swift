import Foundation
import Observation

// MARK: - Device Identity

struct Mbox2Identity {
    let name = "Digidesign Mbox 2"
    let usbVendorID: UInt16 = 0x0DBA
    let usbProductID: UInt16 = 0x3000
}

// MARK: - Connection State

enum Mbox2ConnectionState: String {
    case notDetected = "Not detected"
    case detected = "Detected"
    case unavailable = "Unavailable"
}

// MARK: - USB Communication

enum Mbox2USBState: String {
    case unknown = "Not checked"
    case communicating = "Communicating"
    case notCommunicating = "Not communicating"
}

// MARK: - Driver State

enum Mbox2DriverState: String {
    case notInstalled = "Not installed"
    case installed = "Installed"
    case inactive = "Inactive"
    case unknown = "Unknown"
}

// MARK: - S/PDIF Lock

enum Mbox2SPDIFState: String {
    case unknown = "Unknown"
    case locked = "Locked"
    case unlocked = "Unlocked"
    case unavailable = "Unavailable"
}

// MARK: - Firmware State

enum Mbox2FirmwareState: String {
    case notQueried = "Not queried"
    case available = "Available"
    case unavailable = "Unavailable"
}

// MARK: - Audio Configuration

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

// MARK: - Device Model

@Observable
@MainActor
final class Mbox2Device {

    // Identity
    let identity = Mbox2Identity()

    // Physical connection
    var connectionState: Mbox2ConnectionState = .notDetected

    // USB communication
    var usbState: Mbox2USBState = .unknown

    // Driver
    var driverState: Mbox2DriverState = .notInstalled

    // Digital synchronisation
    var spdifState: Mbox2SPDIFState = .unknown

    // Firmware
    var firmwareState: Mbox2FirmwareState = .notQueried
    var firmwareVersion: String?

    // User-selected configuration.
    // These values are not confirmation of hardware settings.
    var selectedSampleRate: Mbox2SampleRate = .rate44100
    var selectedBitDepth: Mbox2BitDepth = .bit24
    var selectedClockSource: Mbox2ClockSource = .internalClock

    init() {}
}
