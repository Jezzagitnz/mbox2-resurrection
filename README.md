# mBox 2 Resurrection

**An open-source effort to bring the original Digidesign mBox 2 USB audio interface back to life on modern macOS.**

**Project status: Initial DriverKit extension and host-app build/packaging confirmed; AudioDriverKit/USBDriverKit architecture investigation underway.**

## About the project

The original Digidesign mBox 2 was a USB audio interface designed for an earlier generation of Mac and Windows systems. Its original drivers are no longer suitable for modern macOS, leaving otherwise functional hardware difficult to use.

This project investigates the hardware and its communication protocols, studies the original driver architecture, and develops a modern macOS solution for Apple Silicon.

## Hardware scope

The initial target is the **original full-size USB Digidesign Mbox 2** (USB VID `0x0dba`, PID `0x3000`).

The Mbox 2 Mini, Mbox 2 Pro, Mbox 2 Micro and other family products are not assumed to share the same hardware or protocol. They are outside the initial implementation scope.

## Current status

The project has completed substantial investigation of the original Mavericks driver, USB identification, firmware initialisation, USB interface layout and audio-format control. Development has also produced two hardware-independent foundations:

- A minimal DriverKit project scaffold that successfully compiled and packaged on Apple Silicon with Xcode 27.2.
- A transport-independent C++17 protocol module with unit tests; the test suite passed in a clean Linux container.

These milestones are **build and research results, not a functioning driver**. The DriverKit scaffold has not been signed with the required entitlements, installed, activated or tested against the Mbox 2. The protocol module does not communicate with USB hardware.

The current architecture investigation is comparing a properly entitled DriverKit route with a user-space USB engine and Core Audio AudioServerPlugIn approach. A separate Apple Silicon audio-driver project demonstrates that a user-space design can be built without a kernel extension, but its use of USB device-seize fallback is a significant safety concern and is not accepted as a solution for this project.

**No working modern macOS driver, firmware handshake, audio capture or audio playback has yet been demonstrated.**

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
- [Development roadmap](docs/development-roadmap.md) — current status, candidate architectures and staged development plan.
- [DriverKit scaffold status](docs/driverkit-scaffold-status.md) — what was built and packaged, and what remains untested.
- [DriverKit prototype preparation](docs/driverkit-prototype-preparation.md) — the entitlement, signing and safe-activation gates; no security reduction is permitted.

### Research notes

- [Mavericks driver research](research/mavericks-driver.md) — known-working driver components, symbols and disassembly findings.
- [Driver architecture](research/driver-architecture.md) — an initial map of the original driver's components and unanswered relationships.
- [Apple Silicon research](research/apple-silicon.md) — modern target system and current USB detection findings.
- [Modern macOS USB audio observations](research/modern-macos-usb-audio-observations-2026-11-12.md) — read-only interface, Core Audio and system-log findings.
- [Firmware handshake investigation](research/firmware-handshake.md) — identified handshake routines and unanswered questions.
- [Sample-rate, clock and USB stream control](research/sample-rate-clock-control.md) — 44.1/48 kHz selection, USB endpoint requests, external-rate tracking, alternate settings and AC-3 topology.
- [Modern DriverKit architecture](research/driverkit-architecture.md) — USBDriverKit and AudioDriverKit feasibility findings, Linux USB topology, and initialisation/control-request research.

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
