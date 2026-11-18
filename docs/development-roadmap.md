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
