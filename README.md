# mBox 2 Resurrection

**An open-source effort to bring the original Digidesign mBox 2 USB audio interface back to life on modern macOS.**

**Project status: Research and early implementation preparation.**

## About the project

The original Digidesign mBox 2 was a USB audio interface designed for an earlier generation of Mac and Windows systems. Its original drivers are no longer suitable for modern macOS, leaving otherwise functional hardware difficult to use.

This project aims to investigate the hardware and its communication protocols, understand the original driver architecture, and develop a modern macOS solution.

The longer-term goal is to make the original mBox 2 useful again on Apple Silicon Macs.

## Hardware scope

The initial target is the **original full-size USB Digidesign mBox 2**.

Other products in the mBox family — including the mBox 2 Mini and mBox 2 Pro — use different hardware and are not assumed to be compatible. Research into those devices may be useful, but they are outside the initial hardware target.

## Current status

The project has completed substantial investigation of the original driver, USB identification, firmware initialisation and the proposed modern macOS architecture. Work is now moving toward the first DriverKit implementation milestone.

The initial implementation target is a minimal DriverKit extension that matches the original full-size Mbox 2 by USB vendor and product ID and establishes a device connection. Device-specific firmware initialisation and audio transport will be developed in subsequent steps.

**There is not yet a working modern macOS driver.** No DriverKit extension has yet been built or loaded, and device claiming, firmware initialisation and audio input/output have not been validated by the new implementation.

Findings are being documented as the research progresses, with confirmed facts distinguished from hypotheses and areas still requiring investigation.

## Project documentation

### Project planning

- [Project goals](docs/project-goals.md) — intended hardware, functional aims and development principles.
- [Development roadmap](docs/development-roadmap.md) — staged investigation and development plan.

### Research notes

- [Mavericks driver research](research/mavericks-driver.md) — known-working driver components, symbols and disassembly findings.
- [Driver architecture](research/driver-architecture.md) — an initial map of the original driver's components and unanswered relationships.
- [Apple Silicon research](research/apple-silicon.md) — modern target system and current USB detection findings.
- [Modern macOS USB audio observations](research/modern-macos-usb-audio-observations-2026-11-12.md) — 12 November 2026 read-only interface, Core Audio and system-log findings.
- [Firmware handshake investigation](research/firmware-handshake.md) — identified handshake routines and unanswered questions.
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
