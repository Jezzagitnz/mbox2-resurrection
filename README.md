# mBox 2 Resurrection

**An open-source effort to bring the original Digidesign mBox 2 USB audio interface back to life on modern macOS.**

**Project status: User-space implementation selected; USB discovery and interface-6 access demonstrated; device initialisation is the next milestone.**

## About the project

The original Digidesign mBox 2 was a USB audio interface designed for an earlier generation of Mac and Windows systems. Its original drivers are no longer suitable for modern macOS, leaving otherwise functional hardware difficult to use.

This project investigates the hardware and its communication protocols, studies the original driver architecture, and develops a modern macOS solution for Apple Silicon.

## Hardware scope

The initial target is the **original full-size USB Digidesign Mbox 2** (USB VID `0x0dba`, PID `0x3000`).

The Mbox 2 Mini, Mbox 2 Pro, Mbox 2 Micro and other family products are not assumed to share the same hardware or protocol. They are outside the initial implementation scope.

## Current status

The project has selected the **Eleven Rack-style user-space architecture** as its sole implementation path. DriverKit and kernel extensions are not fallback options.

### Confirmed progress

- The original full-size Mbox 2 is identified as USB VID `0x0dba`, PID `0x3000`.
- The device already appears in macOS Audio MIDI Setup. This confirms system enumeration, not working audio I/O.
- Ordinary user-space USB discovery and descriptor reading have been demonstrated.
- An `IOUSBHostInterface` object for interface 6 was successfully initialised using ordinary, non-capture access.
- A standard read-only USB device-descriptor request returned all 18 bytes; the complete 646-byte configuration descriptor has also been read and analysed.
- The existing Host application has been detached from its DriverKit dependency in the local working copy and its standalone macOS target has built successfully with Xcode 27.2. Publication of that project-file change is still pending.
- The transport-independent C++ protocol work and legacy driver reverse-engineering remain available as supporting research.

### Immediate next milestone: initialise the Mbox 2

Establish the correct two-way USB communication and device-initialisation sequence until all Mbox 2 LEDs illuminate. Reconcile the Mavericks driver handshake with the different Linux boot-status sequence before proposing any hardware request. No experimental vendor request or state-changing transfer is authorised by this status note.

### Following milestones

1. **Core Audio:** working playback and capture through macOS, independently of a DAW.
2. **LUNA:** validate real input and output in Universal Audio LUNA after Core Audio operation is stable.

**Not yet demonstrated:** device firmware initialisation, the all-LEDs-on state, USB audio streaming, Core Audio playback/capture, or LUNA operation.

## Security and system-integrity requirements

The primary development Mac must retain **System Integrity Protection (SIP) and normal Startup Security at all times**.

This project will not require or recommend:
- Disabling or reducing SIP.
- Reduced Security or Recovery-mode security changes.
- Kernel extensions or root-only USB access.
- Forced USB device capture, device-seize fallbacks, or terminating Apple's existing USB audio clients to take ownership.

Any USB access experiment must use ordinary, non-forcing access. If macOS denies access because an interface is already owned, the experiment stops. It must not escalate to capture or security reduction.

A build or local experiment is not automatically safe to install. Signing, notarisation, permissions and installation requirements must be assessed and documented before asking users to run software.

## Project documentation

### Project planning

- [Project goals](docs/project-goals.md) — intended hardware, functional aims and non-negotiable development principles.
- [Development roadmap](docs/development-roadmap.md) — confirmed progress and the selected user-space implementation sequence.
- [Implementation foundation — 21 November 2026](docs/implementation-foundation-2026-11-21.md) — session handover, established USB results, architecture decision and next device-initialisation milestone.
- [Historical DriverKit scaffold status](docs/driverkit-scaffold-status.md) — retained as project history; DriverKit is not an active implementation or fallback path.

### Research notes

- [Mavericks driver research](research/mavericks-driver.md) — known-working driver components, symbols and disassembly findings.
- [Driver architecture](research/driver-architecture.md) — an initial map of the original driver's components and unanswered relationships.
- [Apple Silicon research](research/apple-silicon.md) — modern target system, USB descriptor access and interface findings.
- [Modern macOS USB audio observations](research/modern-macos-usb-audio-observations-2026-11-12.md) — read-only interface, Core Audio and system-log findings.
- [18 November hardware detection session](research/hardware-detection-session-2026-11-18.md) — application detection result, unchanged hardware indicators and pending USB-B to USB-C cable test.
- [19 November interface 6 endpoint discovery](research/modern-macos-interface-6-endpoint-discovery-2026-11-19.md) — read-only IOUSBLib endpoint-descriptor query; no interface open or endpoint transfers.
- [Firmware handshake investigation](research/firmware-handshake.md) — identified handshake routines and unanswered questions.
- [Sample-rate, clock and USB stream control](research/sample-rate-clock-control.md) — 44.1/48 kHz selection, USB endpoint requests, external-rate tracking, alternate settings and AC-3 topology.
- [Historical DriverKit architecture research](research/driverkit-architecture.md) — retained for protocol and platform reference only; not an implementation route.

### Hardware notes

- [Reference systems](hardware/reference-systems.md) — known-working legacy system and modern target.
- [USB identification](hardware/usb-identification.md) — device identifiers and the meaning and limits of USB detection.

## Contributing

Contributions and collaboration are welcome. Useful contributions include macOS audio-driver experience, knowledge of original Mbox 2 hardware or firmware, Windows or Linux driver research, USB protocol analysis, hardware documentation, testing and careful technical review.

Please distinguish direct observations from interpretations and hypotheses. Do not publish copyrighted driver binaries, firmware or documentation without permission. See [Contributing](CONTRIBUTING.md) and the [Security policy](SECURITY.md).

## Project principles

- Preserve original hardware wherever possible.
- Prefer documented, reproducible research.
- Distinguish confirmed findings from assumptions.
- Keep SIP and normal Startup Security enabled.
- Never force USB ownership or disrupt existing system clients.
- Avoid unnecessary changes to working legacy systems.
- Treat successful compilation or USB detection as distinct from working audio.
- Build toward a maintainable, open-source solution.

## Licensing

Project-created software and driver code is licensed under the **GNU General Public License v3.0 (GPL-3.0-only)**. Original project documentation is licensed under the **Creative Commons Attribution 4.0 International (CC BY 4.0)** licence.

These licences apply only to material created for this project. Third-party software, firmware, documentation, research and other materials remain subject to their original licences and permissions.

## A note on the project

This is an independent community research project. It is not affiliated with, endorsed by, or supported by Avid or Digidesign.

Digidesign, Avid and mBox are trademarks of their respective owners.
