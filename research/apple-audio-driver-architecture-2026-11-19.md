# Apple Silicon Mbox 2 driver architecture — current platform research

**Date:** 19 November 2026  
**Target:** Original full-size Digidesign Mbox 2 (USB VID `0x0dba`, PID `0x3000`)  
**Development host:** Apple M1 Pro MacBook Pro, macOS 27.0.1, Xcode 27.2  
**Status:** Documentation and API research; no new driver implementation or audio streaming test performed.

## Executive summary

Apple currently documents two relevant user-space USB paths and two audio-publication paths:

1. **IOUSBHost framework (app process):** a host-mode user-space framework that lets an app communicate with custom and non-class-compliant USB devices. This is the framework used by the successful 19 November read-only Mbox 2 descriptor test.
2. **USBDriverKit (DriverKit system extension):** a separate driver framework for a system extension that matches and manages USB hardware.
3. **AudioDriverKit:** Apple's modern audio-driver framework. It connects a DriverKit audio extension directly to the Core Audio HAL and removes the need to implement an Audio Server Plug-in.
4. **Audio Server Plug-in (HAL plug-in):** a separate user-space route that can publish a Core Audio device without a DriverKit audio extension, but it is an alternative architecture, not a required layer when using AudioDriverKit.

The most direct Apple-native architecture for a physical USB audio device is therefore **USBDriverKit + AudioDriverKit**, with the Mbox 2 protocol implemented between them. However, entitlement approval, signing, activation under the project's unchanged security settings, and USB interface matching/ownership remain unresolved gates. This research does not authorise weakening SIP or Startup Security.

For the immediate first pass, the best-supported implementation target is narrower: a read-only discovery and descriptor-inspection layer in the existing macOS utility, using the already demonstrated IOUSBHost app API. This creates useful, testable code without prematurely choosing the final audio-driver transport.

## 1. IOUSBHost framework — app-process USB access

Apple describes IOUSBHost as a host-mode user-space framework for accessing custom and non-class-compliant USB devices from apps. Its classes include `IOUSBHostInterface`, `IOUSBHostPipe` and `IOUSBHostDevice`.

Relevant documented capabilities include:

- Find and initialise a device or interface service.
- Retrieve device, configuration and interface descriptors.
- Send synchronous device requests through the default control endpoint.
- Obtain endpoint pipes for bulk, interrupt and isochronous I/O.
- Enqueue asynchronous I/O, including isochronous requests.

Apple API references:

- [IOUSBHost overview](https://developer.apple.com/documentation/iousbhost/)
- [IOUSBHostInterface](https://developer.apple.com/documentation/iousbhost/iousbhostinterface)
- [IOUSBHostPipe](https://developer.apple.com/documentation/iousbhost/iousbhostpipe)
- [IOUSBHostObject.initWithIOService](https://developer.apple.com/documentation/iousbhost/iousbhostobject/initwithioservice:options:queue:error:interesthandler:)

### What the Mbox 2 test proves

On 19 November, the M1 Pro utility:

1. Enumerated `IOUSBHostInterface` services.
2. Found the original Mbox 2 interface 6 using VID `0x0dba`, PID `0x3000`, and interface number 6.
3. Initialised an `IOUSBHostInterface` object using `IOUSBHostObjectInitOptionsNone`.
4. Successfully sent standard, read-only GET_DESCRIPTOR requests for the device descriptor, configuration header and complete 646-byte configuration descriptor.
5. Destroyed the interface object and released the service normally.

This is direct hardware evidence that the app-process IOUSBHost path can discover interface 6 and perform standard control reads on this Mac with the Mbox 2 connected.

Apple's `initWithIOService` documentation says initialisation creates a communication channel to the kernel and returns nil if the underlying USB service is already open for exclusive access. The successful interface-6 initialisation therefore demonstrates that the service was available to this client at the time of the test. It does not establish that interfaces 0–5 are similarly available, or that endpoint streaming will work.

### Important distinction: IOUSBHost versus USBDriverKit

The app-process IOUSBHost framework and the USBDriverKit framework expose similarly named USB host concepts, but they are different deployment contexts:

- **IOUSBHost:** a framework used by an app or user-space process.
- **USBDriverKit:** a framework used by a DriverKit system extension, with driver matching, transport entitlements and system-extension activation.

The successful app-process test must not be described as a successful DriverKit USB driver test.

### Immediate implementation opportunity

A first-pass read-only discovery module can now be built around the demonstrated app-process API:

- Match only VID `0x0dba` / PID `0x3000`.
- Enumerate interface services and report interface number/class/subclass/protocol.
- Open only the explicitly selected interface using ordinary options.
- Read standard descriptors only.
- Parse the 646-byte configuration descriptor into a structured interface/alternate-setting/endpoint model.
- Release all objects cleanly and report failures without retrying through any seize/capture mechanism.

This module should not automatically send vendor requests, change configurations, select alternate settings, create endpoint pipes, or start transfers.

## 2. Current hardware descriptor findings

The complete descriptor map is recorded in [the 19 November USB control-transfer session](usb-control-transfer-session-2026-11-19.md). The important implementation facts are:

| Interface | Current descriptor evidence | Development significance |
|---:|---|---|
| 0 | Class `0xFE`, subclass `0x01`, protocol `0x00`; seven-byte class-specific descriptor | DFU-related class/subclass identifier only; do not assume a standard DFU implementation |
| 1 | Audio Control | Control descriptors; no endpoint |
| 2 | Audio Streaming; alt 2/3: OUT `0x03` iso 296 bytes and IN `0x83` iso 3 bytes | Playback-related path in Linux; small IN endpoint purpose still requires mapping |
| 3 | Audio Streaming; alt 2/3: OUT `0x04` iso 296 bytes and IN `0x84` iso 3 bytes; alt 6: OUT `0x04` iso 192 bytes | Alternate stream path; alt 6 is associated with AC-3 in legacy analysis |
| 4 | Audio Streaming; alt 2/3: IN `0x85` iso 296 bytes | Linux capture interface |
| 5 | Audio Streaming; alt 2/3: IN `0x86` iso 296 bytes | Additional input path; exact use needs legacy mapping |
| 6 | Vendor-specific; `0x81` interrupt IN 16 bytes, `0x82` bulk IN 16 bytes, `0x02` bulk OUT 16 bytes | Linux maps `0x81`/`0x02` to MIDI; `0x82` remains unexplained |

The PCM AudioStreaming descriptors advertise Type I, two-channel, 24-bit samples in three-byte subframes, with a continuous 8–48 kHz rate range. Descriptor advertisement is not proof that every combination works in the original driver or a new implementation.

Linux's Mbox 2 quirk uses interface 2 alternate setting 2 for playback, interface 4 alternate setting 2 for capture, and interface 6 endpoints `0x02` OUT / `0x81` IN for MIDI. It configures 24-bit, 48 kHz operation. This is a useful reference configuration, not proof that other modes are unsupported.

The 646-byte configuration length read from the physical device exactly matches the Linux quirk's boot-path descriptor-length guard. That is a strong device-match cross-check, not proof that the Linux and Mavericks startup handshakes are interchangeable.

## 3. Audio publication: AudioDriverKit versus Audio Server Plug-in

### AudioDriverKit — direct physical-device route

Apple describes AudioDriverKit as a DriverKit-based audio extension framework that communicates with the Core Audio HAL. It handles the required user-client communication between the HAL and the driver extension, eliminating the need to implement an Audio Server Plug-in.

Apple's current documentation and sample:

- [AudioDriverKit overview](https://developer.apple.com/documentation/audiodriverkit)
- [Creating an audio device driver](https://developer.apple.com/documentation/audiodriverkit/creating-an-audio-device-driver)
- [IOUserAudioDriver](https://developer.apple.com/documentation/audiodriverkit/iouseraudiodriver)

The sample shows the core lifecycle:

- Subclass `IOUserAudioDriver`.
- Create and configure an `IOUserAudioDevice`.
- Add input/output `IOUserAudioStream` objects and supported formats.
- Register the service so Core Audio can see the device.
- Implement start/stop I/O, timestamps, and device configuration changes.
- Coordinate sample-rate or format changes through the AudioDriverKit configuration-change lifecycle.

The sample uses a generated sine signal and loopback; it is an API/lifecycle reference, not a working USB hardware driver. A real Mbox 2 implementation still needs its own USB transport, packet scheduling, clock handling and protocol logic.

Apple's documentation notes that AudioDriverKit is for physical audio devices; for virtual devices Apple recommends an Audio Server Plug-in instead. The Mbox 2 is physical hardware, so AudioDriverKit is the conceptually appropriate direct audio-publication framework if the transport and entitlement gates can be met.

### Audio Server Plug-in — alternative user-space route

Apple also documents a standalone Audio Server Plug-in that can publish a Core Audio device from a `.driver` bundle. This is a separate architecture and may be useful if a supported app-process USB transport can be made to coexist with Core Audio's plug-in lifecycle.

- [Creating an Audio Server Driver Plug-in](https://developer.apple.com/documentation/coreaudio/creating-an-audio-server-driver-plug-in)

A plug-in is not required on top of AudioDriverKit. Avoid designing both layers into the project unless a specific compatibility need justifies that additional complexity.

## 4. DriverKit entitlements, provisioning and security boundary

Apple's current DriverKit entitlement guide states that:

- A DriverKit extension needs the `com.apple.developer.driverkit` entitlement.
- A USB transport driver needs the corresponding USB transport entitlement.
- AudioDriverKit uses the DriverKit Audio Family entitlement.
- The host app needs the System Extensions capability/entitlement to install and activate the extension.
- Apple grants DriverKit entitlements to a development team; they are associated with that team's profile.
- The developer configures an App ID and provisioning profile containing the approved entitlement group.
- The system validates the extension's signed entitlements against the provisioning profile during activation.

References:

- [Requesting Entitlements for DriverKit Development](https://developer.apple.com/documentation/driverkit/requesting-entitlements-for-driverkit-development)
- [DriverKit overview](https://developer.apple.com/documentation/driverkit)
- [Creating a DriverKit development provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-a-driverkit-development-provisioning-profile)

Apple's Audio Server Plug-in + Driver Extension sample explicitly describes an ad-hoc local-testing route that requires disabling SIP to allow ad-hoc-signed DriverKit extensions. That route is incompatible with this project's non-negotiable security boundary and must not be used.

The project's security requirements remain:

- Keep SIP enabled.
- Keep normal Startup Security unchanged.
- Do not use kernel extensions or Reduced Security.
- Do not enter Recovery to change security settings.
- Do not use root-only USB access, forced capture, or seize fallbacks.
- Do not terminate Apple's USB audio clients to take interfaces.

**Unresolved signing question:** Apple's documentation establishes the entitlement and provisioning workflow, but the sources reviewed here do not establish whether this project can obtain the required entitlement group and run a locally developed DriverKit extension with SIP enabled on the target Mac. Do not infer that a paid membership is definitely required or that ad-hoc signing is sufficient. Keep this as a gate to resolve with Apple and the ongoing external driver discussion before committing to the DriverKit route.

## 5. Architecture recommendation and decision gates

### Recommended near-term work

Proceed with the **read-only IOUSBHost discovery/descriptor module** in the existing macOS utility. This is the smallest useful first pass supported by an actual hardware result.

It should provide:
- Device identity and connection state.
- Interface inventory.
- Parsed alternate-setting and endpoint inventory.
- A clear distinction between “descriptor read succeeded” and “device initialised”.
- Diagnostics for access denied, device removed, malformed descriptor and incomplete transfer.
- No automatic vendor requests or endpoint traffic.

### Keep two audio-driver candidates open

| Candidate | Benefit | Gate / risk |
|---|---|---|
| USBDriverKit + AudioDriverKit | Apple's integrated, modern physical audio-driver model; no HAL plug-in layer | Requires Apple-approved entitlements, provisioning/signing and system-extension activation; USB matching/ownership and SIP-enabled development remain unproven |
| App-process IOUSBHost + Audio Server Plug-in | User-space architecture; builds on the IOUSBHost API already exercised | Plug-in lifecycle, permissions, long-running USB I/O, coexistence with `usbaudiod`, and support for the required isochronous traffic remain unproven |

Do not select a production architecture solely because a scaffold compiles or a descriptor read succeeds. First establish the exact entitlement path and the availability of every required interface using ordinary, non-forcing access.

## 6. Explicitly out of scope for the first pass

The first pass must not:

- Send the Mavericks one-byte `0xC0 / 0x85` firmware handshake.
- Send the Linux 18-byte `0xC0 / 0x85` boot-status request.
- Send Linux's subsequent sample-rate setup requests.
- Select any USB configuration or alternate setting.
- Open endpoint pipes or perform endpoint I/O.
- Attempt to control LEDs.
- Claim S/PDIF lock or clock synchronisation.
- Use `USBDeviceOpenSeize()`, `USBInterfaceOpenSeize()`, or any equivalent forced-ownership fallback.

The two known firmware request shapes remain distinct and unapproved. The separate `DigiHandshake::Do()` path remains under investigation; its relationship to S/PDIF synchronisation is an open hypothesis.

## 7. Next research and implementation tasks

1. Implement and test the read-only IOUSBHost device/interface inventory and descriptor parser.
2. Add parser tests using the captured 646-byte descriptor as a fixture, without requiring the hardware to be connected.
3. Inspect the exact IOUSBHost isochronous-pipe API and its timing/buffer requirements for a future proof of concept; do not start endpoint I/O yet.
4. Map the small isochronous IN endpoints on interfaces 2 and 3 and endpoint `0x82` on interface 6 using original-driver disassembly and reliable source evidence.
5. Reconcile the Linux and Mavericks firmware startup paths without sending either request.
6. Resolve the DriverKit entitlement/signing/SIP-enabled development question before choosing USBDriverKit + AudioDriverKit.
7. Continue tracing `DigiHandshake::Do()` against clock-source and external-sample-rate code; do not assume its meaning.

## Sources

- Apple, [IOUSBHost](https://developer.apple.com/documentation/iousbhost/)
- Apple, [IOUSBHostInterface](https://developer.apple.com/documentation/iousbhost/iousbhostinterface)
- Apple, [IOUSBHostPipe](https://developer.apple.com/documentation/iousbhost/iousbhostpipe)
- Apple, [USBDriverKit IOUSBHostInterface](https://developer.apple.com/documentation/usbdriverkit/iousbhostinterface)
- Apple, [AudioDriverKit](https://developer.apple.com/documentation/audiodriverkit)
- Apple, [Creating an audio device driver](https://developer.apple.com/documentation/audiodriverkit/creating-an-audio-device-driver)
- Apple, [Creating an Audio Server Driver Plug-in](https://developer.apple.com/documentation/coreaudio/creating-an-audio-server-driver-plug-in)
- Apple, [Requesting Entitlements for DriverKit Development](https://developer.apple.com/documentation/driverkit/requesting-entitlements-for-driverkit-development)
- Linux, [Mbox 2 quirk implementation](https://github.com/torvalds/linux/blob/master/sound/usb/quirks.c)
- Linux, [Mbox 2 quirk descriptor table](https://github.com/torvalds/linux/blob/master/sound/usb/quirks-table.h)
- Project, [19 November USB control-transfer session](usb-control-transfer-session-2026-11-19.md)
- Project, [development roadmap](../docs/development-roadmap.md)
