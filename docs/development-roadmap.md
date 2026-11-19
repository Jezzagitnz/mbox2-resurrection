# Development roadmap

This roadmap records the current evidence and the intended sequence of work. A planned milestone is not complete until its result has been demonstrated and documented.

## Evidence labels

Use these labels consistently:

- **Confirmed** — directly supported by repeatable observation, source code, or reliable documentation.
- **Strong indication** — supported by evidence, but an important part remains unverified.
- **Hypothesis** — a plausible explanation that needs testing.
- **Open question** — not yet answered by available evidence.
- **Not tested** — no test has yet been performed.

## Current status — November 2026

The project is in **research and early implementation**, not yet at a working-driver stage.

### Completed and evidenced foundations

- **Confirmed:** The original full-size Mbox 2 is identified as USB VID `0x0dba`, PID `0x3000`.
- **Confirmed:** The original driver and relevant firmware-handshake code have been examined on the working Mavericks reference system.
- **Confirmed:** A minimal DriverKit extension and host-app scaffold compiled and packaged on Apple Silicon using Xcode 27.2.
- **Confirmed:** A transport-independent C++17 protocol module was built and its unit tests passed in a clean Linux container.
- **Confirmed:** Modern macOS has existing `usbaudiod` clients attached to several Mbox 2 USB interfaces, creating an interface-ownership question for any replacement transport.

For the detailed build/package evidence and explicit limitations, see [DriverKit scaffold status](driverkit-scaffold-status.md). The proposed secure activation gate is documented separately in [DriverKit prototype preparation](driverkit-prototype-preparation.md).

### Not demonstrated

- DriverKit signing with the required entitlements, installation, activation or runtime loading.
- Successful device matching or ownership by the new implementation.
- Firmware initialisation on modern macOS.
- USB audio transfers, Core Audio device publication, capture or playback.
- 16-bit/24-bit operation, 44.1/48 kHz switching, or internal/external S/PDIF clock behaviour in a new driver.

A successful compile, package, unit test or USB enumeration is not evidence of working audio.

## Non-negotiable security boundary

The primary Mac must keep **SIP enabled and normal Startup Security unchanged**.

The project will not use kernel extensions, Reduced Security, Recovery-mode changes, root-only USB access, forced USB capture, device-seize fallbacks, or termination of Apple's existing USB audio clients to obtain device ownership.

USB experiments must use ordinary, non-forcing access. If the required interface is already owned and normal access is denied, stop and record the result. Do not escalate.

## Candidate architecture investigation

### 1. User-space USB engine with a Core Audio AudioServerPlugIn

This is the current leading route to investigate because it may avoid a kernel extension and DriverKit system-extension activation.

A separate Apple Silicon audio-driver project provides a useful architectural reference: a user-space USB engine communicates with an AudioServerPlugIn through shared memory. Its implementation uses older IOKit USB device interfaces (IOUSBLib), rather than IOUSBHost.

**Important limitation:** that reference implementation attempts `USBDeviceOpenSeize()` when ordinary `USBDeviceOpen()` reports exclusive access. This project explicitly excludes that fallback. It is not yet known whether the Mbox 2 can be used reliably through ordinary, non-forcing access while Apple's existing audio clients are present.

Next questions:
- Can ordinary USB open succeed for the interfaces the Mbox 2 protocol requires?
- Which interfaces are already owned by `usbaudiod`, and can a supported, non-disruptive design coexist with that ownership?
- Can the engine perform the required control transfers and streaming without taking over existing clients?
- Can the AudioServerPlugIn publish stable input/output streams with acceptable latency and lifecycle behaviour?

### 2. DriverKit / AudioDriverKit

A minimal DriverKit scaffold exists and has compiled, but it is not signed, entitled, activated or hardware-tested.

The remaining entitlement, signing, activation and USB interface-ownership requirements must be established from Apple's current requirements. This route is not assumed viable until those gates are understood. No security settings will be weakened to make it work.

### 3. Transport-independent protocol core

The C++ protocol module is deliberately independent of the eventual USB transport. It records the Mavericks one-byte handshake separately from the Linux 18-byte boot-status request, plus known timing and sample-rate facts. The meaning and relationship of the two handshake exchanges remain unresolved.

Keep this core transport-neutral and expand it only when new protocol behaviour is supported by evidence.

## Next development stages

### Stage 1 — Resolve safe USB access

- Study the exact semantics and requirements of ordinary IOUSBLib USB open and the seize operation.
- Compare the Eleven Rack reference architecture without copying its seize fallback.
- Determine the Mbox 2 interfaces required for control, audio and MIDI.
- Establish whether a normal, non-forcing open is possible without disrupting `usbaudiod`.
- Stop if normal access is denied; do not attempt capture or security changes.

### Stage 2 — Complete the protocol model

- Continue mapping the original driver's startup and firmware initialisation sequence.
- Determine the relationship between the Mavericks and Linux handshake exchanges.
- Resolve the clock-source and alternate-setting mappings.
- Establish endpoint and stream-control behaviour from source or repeatable observation.
- Keep confirmed facts separate from hypotheses.

### Stage 3 — Prototype the selected transport

Only after Stage 1 identifies a safe access path:
- Implement a minimal, read-only or otherwise low-risk device communication proof.
- Add the confirmed firmware handshake.
- Record exactly which interfaces and requests are used.
- Keep the protocol core reusable across candidate transports.

### Stage 4 — Build the Core Audio path

- Evaluate device and stream publication through the selected supported macOS audio API.
- Implement input and output independently.
- Verify buffer handling, sample formats and timing.
- Do not claim audio support until real capture and playback are demonstrated.

### Stage 5 — Validate device features

- Test 16-bit and 24-bit operation where supported.
- Test 44.1 kHz and 48 kHz operation.
- Investigate internal clocking and external S/PDIF synchronisation.
- Distinguish device communication from actual clock lock.
- Use Universal Audio LUNA as the initial DAW validation target once basic Core Audio operation is stable.

### Stage 6 — Complete the configuration utility

The native macOS utility should eventually:
- Show whether the Mbox 2 is detected and communicating.
- Show clock source and lock state only when those states can be measured reliably.
- Expose supported sample-rate and format settings.
- Remain focused on essential device configuration.

## Later investigations

Other Mbox-family devices and unrelated audio interfaces are outside the initial target. They should not distract from the original full-size Mbox 2.

## Completion criteria

A stage is complete only when its claims are backed by recorded evidence. Builds, packages, unit tests and device detection are useful milestones, but none independently proves successful firmware initialisation or working audio input and output.

### 19 November 2026 — ordinary USB interface access and control-transfer milestone

- **Confirmed on hardware:** The M1 Pro MacBook Pro enumerated the original Mbox 2 IOUSBHostInterface services and found interface 6 using registry properties for VID 0x0dba, PID 0x3000, and interface number 6.
- **Confirmed on hardware:** An IOUSBHostInterface object for interface 6 was created with ordinary IOUSBHostObjectInitOptionsNone access, then destroyed and released successfully.
- **Confirmed on hardware:** Through that interface object, one standard, read-only USB GET_DESCRIPTOR device-descriptor request completed successfully. All 18 requested bytes were transferred and the returned descriptor identified VID 0x0dba, PID 0x3000, device revision 0x0138.
- **Important boundary:** This proves ordinary interface access and one successful USB control transfer. It does **not** prove firmware initialisation, device/engine activation, LED control, audio streaming, Core Audio publication, or audio input/output.
- **Not attempted:** No seize/capture operation, configuration change, alternate-setting change, pipe creation, endpoint transfer, firmware handshake, sample-rate request, or audio streaming operation was performed.
- **LED expectation:** A standard device-descriptor read does not request hardware initialisation or an LED-state change. No LED response is expected from this test. The physical LED state after the descriptor request was not recorded as part of the transfer output.

See [the 19 November USB control-transfer session record](../research/usb-control-transfer-session-2026-11-19.md) for the request fields, exact returned bytes, parsing, cleanup, and limitations.


### 19 November 2026 — configuration descriptor cross-check

- **Confirmed on hardware:** A second standard, read-only GET_DESCRIPTOR request returned the 9-byte configuration header: `09 02 86 02 07 01 00 80 FA`.
- **Confirmed on hardware:** The header reports a total configuration length of **646 bytes**, seven interfaces, configuration value 1, bus-powered attributes, and 500 mA maximum power.
- **Strong cross-check:** The 646-byte total exactly matches the configuration-length prerequisite used by the Linux Mbox 2 boot quirk. This supports the conclusion that the Linux quirk recognises this hardware configuration.
- **Important limitation:** The matching length does not prove that the Linux boot-status request or its subsequent initialisation steps are interchangeable with the Mavericks driver sequence, nor does it authorise sending either request.
- **Not attempted:** No full configuration read, configuration selection/change, alternate-setting change, firmware/vendor request, endpoint transfer, sample-rate request, or audio operation.
- **Next:** Continue static comparison of the two startup paths before proposing any further hardware request.

The exact request, returned bytes, parsing, and safety boundaries are recorded in [the 19 November USB control-transfer session record](../research/usb-control-transfer-session-2026-11-19.md).


### 19 November 2026 — complete configuration descriptor parsed

- **Confirmed on hardware:** A standard read-only GET_DESCRIPTOR request returned the full 646-byte configuration descriptor through ordinary IOUSBHost access to interface 6.
- **Confirmed:** Offline parsing identified seven interfaces, their alternate settings, and all endpoint addresses, directions, transfer types and maximum packet sizes. The detailed map is in [the USB control-transfer session record](../research/usb-control-transfer-session-2026-11-19.md).
- **Confirmed from descriptors:** The PCM AudioStreaming paths advertise Type I, two-channel, 24-bit samples in three-byte subframes, with a continuous 8–48 kHz range.
- **Strong cross-check:** Interface 6 endpoints `0x02` OUT and `0x81` IN match the MIDI endpoints used by the Linux quirk. Endpoint `0x82` IN remains unexplained.
- **Important caution:** Interface 0 has a DFU-related class/subclass identifier, but the seven-byte class-specific descriptor is not enough to claim a standard operational DFU interface.
- **Not attempted:** No endpoint pipe or endpoint transfer, alternate-setting change, firmware request, USB reset, sample-rate operation or audio streaming was performed.
