# Implementation foundation — 21 November 2026

**Project:** Original full-size Digidesign Mbox 2 (VID `0x0dba`, PID `0x3000`)  
**Target:** Apple Silicon Mac, macOS 27.0.1, Xcode 27.2  
**Status:** USB discovery and interface-6 access demonstrated; next milestone is device initialisation.

## Architecture decision

The project will use the **Eleven Rack-style user-space architecture as its sole implementation path**.

There is no DriverKit or kernel-extension fallback. The implementation must not use forced USB device capture/seize, root-only takeover, or terminate Apple's USB audio services to obtain access. SIP and normal Startup Security remain enabled.

The intended design separates ordinary user-space USB transport, a transport-independent Mbox 2 protocol core, Core Audio input/output, and a small configuration utility. The exact helper and Core Audio plug-in lifecycle still needs to be validated; do not treat it as solved.

## Established results — do not repeat

### Device visibility and USB discovery

- The Mbox 2 already appears in macOS Audio MIDI Setup. This is enumeration only; it does not establish working audio I/O.
- Ordinary user-space USB discovery identified the original full-size Mbox 2.
- The device identity is VID `0x0dba`, PID `0x3000`, revision `0x0138`.

### Interface 6 and descriptor access

- An ordinary `IOUSBHostInterface` object for interface 6 was successfully initialised with `IOUSBHostObjectInitOptionsNone`.
- The object was released cleanly.
- A standard read-only GET_DESCRIPTOR device request through that object returned all 18 bytes.
- The complete 646-byte configuration descriptor was read and parsed offline.
- Seven interfaces, alternate settings and endpoint topology have been recorded.

This proves ordinary access to interface 6 and successful standard control reads. It does not prove the firmware handshake, operational device initialisation, LED control or audio transfers.

### Standalone Host application

- The existing Host app already existed; no duplicate application was created.
- Its local Xcode project was edited to remove the Host target's DriverKit dependency and System Extensions embedding phase.
- The project file passed `plutil -lint`.
- The existing DriverKit target remains separately defined in the local project, but it is not an implementation fallback.
- The existing Host target built successfully on 21 November 2026 with Xcode 27.2.
- This was an app build only. The standalone app has not yet been shown to perform the previously proven USB operations. The project-file edit is still pending publication to the repository.

## Immediate next milestone — device initialisation

The next task is **two-way USB communication sufficient to initialise the Mbox 2 until all expected LEDs illuminate**.

Research must reconcile the legacy Mavericks driver's one-byte firmware handshake with the different Linux 18-byte boot-status request. Their request fields, ordering, expected responses and retry behaviour must be understood before any hardware test is proposed.

No firmware/vendor-specific or state-changing USB request is authorised by this note. First establish the sequence from source and existing evidence; then explain the exact proposed test and obtain explicit approval.

## Following milestones

1. **Core Audio:** working playback and capture through macOS, tested independently of a DAW. Audio MIDI Setup visibility alone does not count.
2. **Universal Audio LUNA:** validate real playback and recording after Core Audio input and output work.
3. **Device features:** investigate 16/24-bit formats, 44.1/48 kHz operation, and internal/external S/PDIF clocking after basic audio works.

## Session rules

- Start at device-initialisation research, not USB discovery.
- Do not repeat Audio MIDI Setup visibility, descriptor capture, or interface-6 attachment.
- Reuse existing reverse-engineering findings and protocol notes.
- Keep confirmed facts separate from hypotheses.
- Do not force USB ownership or weaken macOS security.
- Work in short, self-contained Terminal steps.
- Keep this project separate from RAVUNA.

## Primary research references

- [Mavericks driver research](../research/mavericks-driver.md)
- [Firmware handshake investigation](../research/firmware-handshake.md)
- [Sample-rate, clock and USB stream control](../research/sample-rate-clock-control.md)
- [19 November USB control-transfer session](../research/usb-control-transfer-session-2026-11-19.md)
- [Development roadmap](development-roadmap.md)
