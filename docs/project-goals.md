# Project goals

## Main goal

Develop an open-source way to use the original, full-size Digidesign Mbox 2 USB audio interface on modern macOS, with Apple Silicon as the primary target.

The initial development target is the user's Apple Silicon MacBook Pro with an M1 Pro processor. The intended modern macOS target is currently referred to in this project as **Golden Gate**. Universal Audio LUNA is the initial digital audio workstation (DAW) target for eventual practical use.

These are project goals, not claims that support has already been achieved.

## Functional goals

The research and development work will investigate whether the modern solution can provide:

- Audio input and output through CoreAudio.
- 16-bit and 24-bit audio.
- 44.1 kHz and 48 kHz sample rates, with 44.1 kHz prioritised for music work.
- Internal clock operation.
- External S/PDIF clock synchronisation, if the hardware and protocol support it.
- Clear status reporting that distinguishes USB/device communication from actual S/PDIF clock lock.

The achievable formats and clocking options must be established from hardware and software evidence. They should not be assumed from the capabilities of other Mbox models.

## Configuration utility

A small native macOS utility is a longer-term goal. It should make essential device status and settings accessible without recreating a full mixer or digital audio workstation.

The initial utility concept is Mbox 2-specific. Its design should remain modular enough that research from other legacy interfaces could inform future work, without promising support for devices that have not been investigated.

## Initial hardware scope

The first target is the original full-size USB Digidesign Mbox 2.

The Mbox 2 Mini, Mbox 2 Pro, Mbox 2 Micro and other Mbox-family products are not assumed to share the same hardware, firmware or driver behaviour. They are outside the initial implementation scope unless evidence and community contributions justify expanding it.

## Development principles

- Keep known-working legacy systems available as reference environments.
- Prefer reproducible observations and documented evidence.
- Separate confirmed facts, interpretations, hypotheses and unanswered questions.
- Avoid treating successful USB detection as proof that audio streaming works.
- Design for maintainability and future macOS changes where practical.
- Keep project-created driver and software code open source under GPL-3.0-only.
- License original project documentation under CC BY 4.0.
- Respect the original licences and permissions of all third-party material.

## Current status

The project is in the research and investigation stage. The original driver has been examined on a working Mavericks reference system, and the Mbox 2 has been detected by the USB system on Apple Silicon.

A working modern macOS driver has **not** yet been produced. Successful firmware initialisation, CoreAudio operation and audio streaming on the modern target remain to be demonstrated.
