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

**The first DriverKit project scaffold has been authored locally. Xcode project discovery is now confirmed, and standalone IIG generation has been demonstrated; the complete native build is still pending.** The scaffold contains a DriverKit extension target, a minimal `IOService` start implementation, USB matching metadata for the original full-size Mbox 2 (VID `0x0dba`, PID `0x3000`), and a small host-app target.

The target configuration-list references in the hand-authored Xcode project have been corrected. `xcodebuild -list` now recognises both `Mbox2Driver` and `Mbox2DriverHost` and their Debug/Release configurations.

The first native DriverKit build reached C++ compilation but stopped because the generated `Mbox2Driver.h` was not available. A standalone run of Apple's IIG compiler has since succeeded when invoked with `-D__IIG=1`, producing the generated class header and dispatch implementation. Automatic IIG generation and generated-source compilation are the current integration task; a successful full build has not yet been demonstrated.

**This is not yet a working DriverKit implementation.** The local scaffold has not completed a native build, been packaged into its host app, signed or loaded, or claimed the Mbox 2. The scaffold has not yet been committed as driver source in the public repository.

The next work is deliberately incremental:

1. Integrate the confirmed IIG compiler invocation into the Xcode build.
2. Complete a native DriverKit build and resolve any remaining compiler, framework or build-setting issues.
3. Add the proper host-app dependency and system-extension embedding/activation flow.
4. Establish the required signing, provisioning and DriverKit entitlement path before attempting activation.
5. Only then, when the hardware is available, test USB matching, device ownership and the device-specific protocol.

SDK and template availability do not prove that the required entitlements, device ownership or runtime behaviour will work. The USB match and service-start code are only the first scaffold; they do not implement firmware initialisation or audio.

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
