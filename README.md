# mBox 2 Resurrection

**An open-source effort to bring the original Digidesign mBox 2 USB audio interface back to life on modern macOS.**

**Project status: Research and development.**

## About the project

The original Digidesign mBox 2 was a USB audio interface designed for an earlier generation of Mac and Windows systems. Its original drivers are no longer suitable for modern macOS, leaving otherwise functional hardware difficult to use.

This project aims to investigate the hardware and its communication protocols, understand the original driver architecture, and develop a modern macOS solution.

The longer-term goal is to make the original mBox 2 useful again on Apple Silicon Macs.

## Hardware scope

The initial target is the **original full-size USB Digidesign mBox 2**.

Other products in the mBox family — including the mBox 2 Mini and mBox 2 Pro — use different hardware and are not assumed to be compatible. Research into those devices may be useful, but they are outside the initial hardware target.

## Current status

This project is in the investigation stage. Work is focused on understanding the original hardware, its firmware initialisation, USB communication, and the software architecture required to support it on modern macOS.

**There is not yet a working modern macOS driver.**

Findings are being documented as the research progresses, with confirmed facts distinguished from hypotheses and areas still requiring investigation.

## Project documentation

### Project planning

- [Project goals](docs/project-goals.md) — intended hardware, functional aims and development principles.
- [Development roadmap](docs/development-roadmap.md) — staged investigation and development plan.

### Research notes

- [Mavericks driver research](research/mavericks-driver.md) — known-working driver components, symbols and disassembly findings.
- [Apple Silicon research](research/apple-silicon.md) — modern target system and current USB detection findings.
- [Firmware handshake investigation](research/firmware-handshake.md) — identified handshake routines and unanswered questions.

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
