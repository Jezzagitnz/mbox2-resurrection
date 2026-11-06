# Development roadmap

This roadmap describes the intended investigation and development sequence. It is not a claim that any stage is complete.

## Status labels

Use these labels consistently in project notes:

- **Confirmed** — directly supported by repeatable observation, source code, or reliable documentation.
- **Strong indication** — supported by evidence, but an important part remains unverified.
- **Hypothesis** — a plausible explanation that needs testing.
- **Open question** — not yet answered by available evidence.
- **Not tested** — no test has yet been performed.

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
