# Project goals

## Main goal

Develop an open-source way to use the original, full-size Digidesign Mbox 2 USB audio interface on modern macOS, with Apple Silicon as the primary target.

The initial development target is an Apple Silicon MacBook Pro with an M1 Pro processor. The intended modern macOS target is currently referred to in this project as **Golden Gate**. Universal Audio LUNA is the initial digital audio workstation (DAW) target for eventual practical use.

These are project goals, not claims that support has already been achieved.

## Functional goals

The research and development work will investigate whether the modern solution can provide:

- Audio input and output through Core Audio.
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

The first target is the original full-size USB Digidesign Mbox 2 (USB VID `0x0dba`, PID `0x3000`).

The Mbox 2 Mini, Mbox 2 Pro, Mbox 2 Micro and other Mbox-family products are not assumed to share the same hardware, firmware or driver behaviour. They are outside the initial implementation scope unless evidence and community contributions justify expanding it.

## Selected implementation method

The sole active implementation method is the **Eleven Rack-style user-space architecture**, adapted for macOS:

- Ordinary user-space USB communication for device protocol and transport.
- A transport-independent Mbox 2 protocol core.
- A dedicated audio engine/transport path connected to Core Audio through the supported macOS audio plug-in architecture.
- Shared-memory audio transport where appropriate to bridge the USB process and Core Audio component safely.
- A small native macOS configuration utility for device status and supported settings.

This is an architectural choice, not a claim that the complete implementation is already working. The exact process boundary, AudioServerPlugIn lifecycle, shared-memory design, permissions, signing and packaging still require implementation and validation.

**DriverKit is parked and is not part of the current plan.** Do not continue DriverKit development, use it as a fallback, or spend time investigating it unless the project owner explicitly reopens that decision. The existing experimental scaffold is not the basis for future work.

## Non-negotiable security requirements

The primary development Mac must retain **System Integrity Protection (SIP) enabled and normal Startup Security**.

The project must not require or recommend:
- Disabling or reducing SIP.
- Reduced Security or Recovery-mode security changes.
- Kernel extensions or root-only USB access.
- Forced USB device capture, device-seize fallbacks, or terminating Apple's existing USB audio clients to take ownership.

Any USB access test must use ordinary, non-forcing access. If macOS denies access because an interface is already owned, the test stops. It must not escalate to capture or security reduction.

Software signing, notarisation, permissions and installation risks must be assessed before asking users to install or run a build. A successful build does not imply that the result is safe or ready to install.

## Development principles

- Keep known-working legacy systems available as reference environments.
- Prefer reproducible observations and documented evidence.
- Separate confirmed facts, interpretations, hypotheses and unanswered questions.
- Avoid treating successful USB detection as proof that audio streaming works.
- Design for maintainability and future macOS changes where practical.
- Keep project-created driver and software code open source under GPL-3.0-only.
- License original project documentation under CC BY 4.0.
- Respect the original licences and permissions of all third-party material.
- Keep the original full-size Mbox 2 as the sole initial hardware target.

## Current status — 22 November 2026

The user-space architecture is selected. Ordinary USB discovery, interface-6 access and standard read-only descriptor transfers have been demonstrated on the modern Mac. The transport-independent protocol core exists and its hardware-independent tests have passed.

The next milestone is the first justified, explicitly approved bidirectional USB communication needed to initialise the Mbox 2 and reach its expected illuminated LED state. Only after that should work progress to genuine Core Audio input and output.

No firmware initialisation, expected LED state, USB audio streaming, Core Audio input/output or LUNA operation has yet been demonstrated on the modern Mac. DriverKit work is parked and is not a project milestone or fallback.
