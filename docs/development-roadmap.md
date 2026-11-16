# Development roadmap

This roadmap describes the intended investigation and development sequence. It is not a claim that any stage is complete.

## Status labels

Use these labels consistently in project notes:

- **Confirmed** — directly supported by repeatable observation, source code, or reliable documentation.
- **Strong indication** — supported by evidence, but an important part remains unverified.
- **Hypothesis** — a plausible explanation that needs testing.
- **Open question** — not yet answered by available evidence.
- **Not tested** — no test has yet been performed.

## Current development status — 17 November 2026

**The initial DriverKit extension and host-app scaffold now builds and packages successfully.** The Xcode project contains a minimal `IOService`-based DriverKit extension, USB matching metadata for the original full-size Mbox 2 (VID `0x0dba`, PID `0x3000`), an IIG generation build phase, and a macOS host app that embeds the extension under `Contents/Library/SystemExtensions`.

The packaged extension has a valid root `Info.plist`, a declared executable name and an arm64 Mach-O binary. This confirms build and packaging only; it does not establish signing, activation, device ownership or audio operation.

The active DriverKit 27.2 SDK contains both USBDriverKit and AudioDriverKit. Header inspection confirmed the presence of `IOUserAudioDriver`, `IOUserAudioDevice`, `IOUserAudioStream`, and USB host device/interface/pipe APIs.

**The key open architecture question is USB audio support.** Apple's general DriverKit documentation contains a restriction concerning USB devices that manipulate audio, while AudioDriverKit documentation and its sample describe hardware audio drivers communicating over USB or PCI. The precise supported architecture and entitlement path for this Mbox 2 use case must be established before implementation proceeds.

The scaffold has not been signed, activated or loaded. It has not claimed the Mbox 2, performed the firmware handshake, implemented USB audio transfers, or published an AudioDriverKit device to Core Audio.

The next work is deliberately incremental:

1. Reconcile Apple's USB-audio restriction with the AudioDriverKit hardware-communication model and current USB transport APIs.
2. Study the AudioDriverKit sample and relevant SDK declarations to establish a supported driver structure.
3. Design a minimal AudioDriverKit driver/device skeleton and build it independently of unverified USB behaviour.
4. Establish the signing, provisioning and entitlement requirements before attempting activation.
5. Implement and test device matching, firmware initialisation and USB transport when the hardware is available.
6. Implement audio streams, clocking and Core Audio publication, then validate real capture and playback.

SDK and template availability do not prove that the required entitlements, device ownership or runtime behaviour will work. A successful build or package is not proof of working audio.

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

## Stage 4 — Design a modern implementation

- Identify which parts of the old driver behaviour are essential.
- Evaluate current macOS audio-driver approaches and their support for the target macOS release.
- Resolve the documented USB-audio restrictions and required entitlements before choosing a transport architecture.
- Separate device communication, audio transport and user-facing configuration where practical.
- Design for Apple Silicon and maintainability across future macOS releases.
- Document security, signing, installation and system-permission requirements before proposing installation steps.

## Stage 5 — Validate audio operation

- Establish repeatable device initialisation.
- Test input and output independently.
- Test 16-bit and 24-bit operation where supported.
- Test 44.1 kHz and 48 kHz operation where supported.
- Test internal and external clock modes where supported.
- Verify real audio capture and playback, not merely device detection.

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
