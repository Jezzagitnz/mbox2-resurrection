# mBox 2 Resurrection

**An open-source effort to bring the original Digidesign mBox 2 USB audio interface back to life on modern macOS.**

## About the project

The original Digidesign mBox 2 was a USB audio interface designed for an earlier generation of Mac and Windows systems. Its original drivers are no longer suitable for modern macOS, leaving otherwise functional hardware difficult to use.

This project aims to investigate the hardware and its communication protocols, understand the original driver architecture, and develop a modern macOS solution.

The longer-term goal is to make the original mBox 2 useful again on Apple Silicon Macs.

## Hardware scope

The initial target is the **original full-size USB Digidesign mBox 2**.

Other products in the mBox family — including the mBox 2 Mini and mBox 2 Pro — use different hardware and are not assumed to be compatible. Research into those devices may be useful, but they are outside the initial hardware target.

## Current status

<badge>Research and development</badge>

This project is in the investigation stage. Work is focused on understanding the original hardware, its firmware initialisation, USB communication, and the software architecture required to support it on modern macOS.

**There is not yet a working modern macOS driver.**

Findings will be documented as the research progresses, with confirmed facts distinguished from hypotheses and areas still requiring investigation.

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

## A note on the project

This is an independent community research project. It is not affiliated with, endorsed by, or supported by Avid or Digidesign.

Digidesign, Avid and mBox are trademarks of their respective owners.
