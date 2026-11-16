# mBox 2 Resurrection

**An open-source effort to bring the original Digidesign mBox 2 USB audio interface back to life on modern macOS.**

**Project status: Initial DriverKit extension and host-app build/packaging confirmed; AudioDriverKit/USBDriverKit architecture investigation underway.**

## About the project

The original Digidesign mBox 2 was a USB audio interface designed for an earlier generation of Mac and Windows systems. Its original drivers are no longer suitable for modern macOS, leaving otherwise functional hardware difficult to use.

This project aims to investigate the hardware and its communication protocols, understand the original driver architecture, and develop a modern macOS solution.

The longer-term goal is to make the original mBox 2 useful again on Apple Silicon Macs.

## Hardware scope

The initial target is the **original full-size USB Digidesign mBox 2**.

Other products in the mBox family — including the mBox 2 Mini and mBox 2 Pro — use different hardware and are not assumed to be compatible. Research into those devices may be useful, but they are outside the initial hardware target.

## Current status

The local development working copy now contains a minimal DriverKit extension target, USB matching metadata for the original full-size Mbox 2 (VID `0x0dba`, PID `0x3000`), an Xcode build phase that generates the IIG interface files, and a macOS host app.

**The minimal DriverKit extension and host app build successfully.** The extension is embedded in the host app under `Contents/Library/SystemExtensions`. Its packaged Info.plist and arm64 executable have been checked. This is a build-and-packaging milestone only, not a working driver.

The active DriverKit 27.2 SDK contains both USBDriverKit and AudioDriverKit. The installed headers expose audio-driver, audio-device, audio-stream, USB-device, USB-interface and USB-pipe APIs.

The next architectural question is how Apple's documented USB-audio restrictions apply to an AudioDriverKit hardware driver communicating with this particular USB audio interface. That must be resolved, along with the required entitlements, before committing to an implementation design.

**There is not yet a working modern macOS driver.** The extension has not been signed, activated or loaded; it has not claimed the Mbox 2; and firmware initialisation, USB audio transport, AudioDriverKit publication, capture and playback remain unimplemented or unvalidated.

See [the current DriverKit scaffold status](docs/driverkit-scaffold-status.md) and the [development roadmap](docs/development-roadmap.md) for the next steps. Findings continue to distinguish confirmed facts from hypotheses and work that has not yet been tested.

## Project documentation

### Project planning

- [Project goals](docs/project-goals.md) — intended hardware, functional aims and development principles.
- [Development roadmap](docs/development-roadmap.md) — staged investigation and development plan.
- [DriverKit scaffold status](docs/driverkit-scaffold-status.md) — current implementation checkpoint, build/package evidence, architecture question and next steps.

### Research notes

- [Mavericks driver research](research/mavericks-driver.md) — known-working driver components, symbols and disassembly findings.
- [Driver architecture](research/driver-architecture.md) — an initial map of the original driver's components and unanswered relationships.
- [Apple Silicon research](research/apple-silicon.md) — modern target system and current USB detection findings.
- [Modern macOS USB audio observations](research/modern-macos-usb-audio-observations-2026-11-12.md) — 12 November 2026 read-only interface, Core Audio and system-log findings.
- [Firmware handshake investigation](research/firmware-handshake.md) — identified handshake routines and unanswered questions.
- [Sample-rate, clock and USB stream control](research/sample-rate-clock-control.md) — 44.1/48 kHz selection, USB endpoint requests, external-rate tracking, alternate settings and AC-3 topology.
- [Modern DriverKit architecture](research/driverkit-architecture.md) — public USBDriverKit and AudioDriverKit feasibility findings, Linux USB topology, and initialisation/control-request research.

### Hardware notes

- [Reference systems](hardware/reference-systems.md) — known-working legacy system and modern target.
- [USB identification](hardware/usb-identification.md) — device identifiers and the meaning and limits of USB detection.

## Contributing

Contributions and collaboration are very welcome.

Useful contributions could include:

- Experience with macOS audio drivers, CoreAudio, IOKit or USB audio.
- Knowledge of the original Digidesign mBox 2 hardware or firmware.
- Windows or Linux driver research.
- USB protocol analysis, reverse engineering or hardware documentation.
- Access to other original mBox 2 hardware revisions for comparison.
- Testing, documentation, and ideas for a maintainable open-source implementation.

If you have relevant information, hardware, or experience, please get in touch through GitHub Issues or Discussions.

Before submitting work, please read [Contributing](CONTRIBUTING.md). For security concerns, see [Security policy](SECURITY.md).

Even small pieces of reliable information may help move the project forward.

## Project principles

- Preserve original hardware wherever possible.
- Prefer documented, reproducible research.
- Distinguish confirmed findings from assumptions.
- Avoid unnecessary changes to working legacy systems.
- Build toward a maintainable, open-source solution.

## Licensing

The software and driver code developed by this project is licensed under the **GNU General Public License v3.0 (GPL-3.0-only)**.

This means that anyone may use, study, modify, and redistribute the software under the terms of that licence. If someone distributes a modified version, they must make the corresponding source code available under the same licence.

Original project documentation, including research notes and written guides, is licensed under the **Creative Commons Attribution 4.0 International (CC BY 4.0)** licence.

These licences apply only to material created for this project. Third-party software, firmware, documentation, research, and other materials remain subject to their original licences and permissions. They are not automatically relicensed by this project.

## A note on the project

This is an independent community research project. It is not affiliated with, endorsed by, or supported by Avid or Digidesign.

Digidesign, Avid and mBox are trademarks of their respective owners.
