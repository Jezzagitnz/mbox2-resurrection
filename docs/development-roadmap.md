# Development roadmap

This roadmap describes the intended investigation and development sequence. It is not a claim that any stage is complete.

## Status labels

Use these labels consistently in project notes:

- **Confirmed** — directly supported by repeatable observation, source code, or reliable documentation.
- **Strong indication** — supported by evidence, but an important part remains unverified.
- **Hypothesis** — a plausible explanation that needs testing.
- **Open question** — not yet answered by available evidence.
- **Not tested** — no test has yet been performed.

## Current development status — November 2026

The project now has a minimal DriverKit source scaffold on the separate `driverkit-foundation` branch (PR #14). A local Xcode 27.2 build and packaging result are recorded there. This is a compile/package milestone only: signing, entitlement approval, activation, USB ownership, firmware initialisation and audio remain untested.

A second architecture is being investigated in parallel: an ordinary user-space IOUSBHost helper connected to a Core Audio Audio Server Plug-in. Apple's public APIs make this technically plausible without a DriverKit USB extension, but the Mbox 2's required interfaces were previously observed with `usbaudiod` clients attached. Normal IOUSBHost access is exclusive, so access without device capture is the first hard test.

**Security constraint:** SIP and Startup Security on the primary Mac must remain unchanged. Do not use kernel extensions, ad-hoc DriverKit activation that requires disabling security checks, root-only device capture, or `IOUSBHostObjectInitOptionsDeviceCapture`. If a test cannot proceed under normal security, stop and record the blocker.

See [SIP-compatible user-space USB and Core Audio path](../research/sip-compatible-user-space-path.md) for the architecture comparison, API evidence and decision gates.

## Stage 1 — Organise the evidence

- Record the known-working legacy system and its software versions.
- Record modern Mac hardware and operating-system details.
- Preserve command output, disassembly observations and relevant file versions.
- Separate observations from interpretations.
- Record the source and context for every important finding.

## Stage 2 — Understand device initialisation

- Map the original driver's device-matching and startup sequence.
- Identify the firmware handshake stages and the USB requests associated with them.
- Determine what successful initialisation looks like in logs and device state.
- Compare behaviour across systems where reliable evidence is available.
- Avoid assuming that USB enumeration alone means the device is ready.

## Stage 3 — Understand the audio path

- Identify how the original driver exposes the device to CoreAudio.
- Establish the supported input/output channels and audio formats.
- Determine how sample rate and bit depth are selected.
- Investigate internal clocking and external S/PDIF synchronisation.
- Distinguish device communication, clock synchronisation and active audio streaming.

## Stage 4 — Design and implement a modern transport

Evaluate and keep separate the two viable candidates until evidence selects one:

1. **DriverKit + AudioDriverKit:** use the approved DriverKit/USB transport entitlements and normal signed activation path. Do not use Apple's SIP-disabling ad-hoc development workaround.
2. **IOUSBHost + Audio Server Plug-in:** use a user-space USB helper and a plug-in/helper IPC boundary. Prove ordinary interface access without device capture or disrupting Apple's services before investing in the full audio path.

In parallel:

- Keep Mbox protocol logic independent of the USB transport.
- Add automated tests for confirmed request construction, response parsing and state transitions.
- Use a preallocated, bounded audio ring for any eventual real-time bridge.
- Verify all API signatures and deployment requirements against the installed macOS 27 SDK before implementation.

## Stage 5 — Validate device operation and audio

- Establish repeatable device initialisation.
- Test input and output independently.
- Test 16-bit and 24-bit operation where supported.
- Test 44.1 kHz and 48 kHz operation where supported.
- Test internal and external clock modes where supported.
- Verify real audio capture and playback, not merely device detection.
- Perform all tests with SIP and normal Startup Security enabled.

## Stage 6 — Build a configuration utility

Once the underlying driver and device controls are understood:

- Show whether the device is detected and communicating.
- Show actual clock source and lock state only when those states can be measured reliably.
- Expose supported sample-rate and format settings.
- Keep the utility focused on essential configuration rather than mixing or DAW features.

## Later investigations

Possible later work includes other Mbox-family devices, the Mbox 2 Micro, standalone USB-powered behaviour, and the Focusrite Saffire Pro 26. These are separate investigations and should not distract from the original full-size Mbox 2 target.

## Completion criteria

A stage should be marked complete only when its claims are backed by recorded evidence. A successful build or device detection is not, by itself, proof of working audio input and output.
