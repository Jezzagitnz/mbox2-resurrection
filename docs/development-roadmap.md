# Development roadmap

This roadmap records the current evidence and the intended sequence of work. A planned milestone is not complete until its result has been demonstrated and documented.

## Evidence labels

Use these labels consistently:

- **Confirmed** — directly supported by repeatable observation, source code, or reliable documentation.
- **Strong indication** — supported by evidence, but an important part remains unverified.
- **Hypothesis** — a plausible explanation that needs testing.
- **Open question** — not yet answered by available evidence.
- **Not tested** — no test has yet been performed.

## Current status — 22 November 2026

The project has selected the **Eleven Rack-style user-space architecture** as its sole implementation path. DriverKit and kernel extensions are not fallback options.

### 22 November clarification — startup evidence and next milestone

The latest static review confirms the Mavericks driver's `FirmwareHandshake(false)` request is a one-byte vendor control read (`0xC0 / 0x85`, `wValue=1`, `wIndex=1`, `wLength=1`). A successful response containing `0x01` causes a 300 ms delay and retry, with up to 30 retries after the initial attempt. In the inspected `initHardware()` path, interface-rematching calls for interfaces 0 and 6 precede this handshake on the relevant branch; the concrete `RayDevice::CreateAudioEngines()` override follows successful setup.

The Linux boot quirk uses the same request type/code but a distinct 18-byte request (`wIndex=0`, `wLength=18`) and a different response interpretation and polling schedule. These exchanges must remain separate until their relationship is established. A separate five-stage `DigiHandshake::Do` mechanism is present, but its stage operations and relationship to startup remain unresolved. The short 22 November review did not inspect those helper bodies because the user could not run the final command; do not record that analysis as complete.

### Completed and evidenced foundations

- **Confirmed:** The original full-size Mbox 2 is identified as USB VID `0x0dba`, PID `0x3000`.
- **Confirmed:** The device already appears in macOS Audio MIDI Setup. This is device enumeration, not proof of working audio.
- **Confirmed:** Ordinary user-space USB discovery has identified the device and read its descriptors.
- **Confirmed:** An `IOUSBHostInterface` object for interface 6 was initialised using ordinary `IOUSBHostObjectInitOptionsNone` access, then released cleanly.
- **Confirmed:** Through that interface object, a standard read-only USB GET_DESCRIPTOR device request returned all 18 bytes and identified the Mbox 2.
- **Confirmed:** The full 646-byte configuration descriptor has been read and parsed; seven interfaces and their alternate settings/endpoints are documented.
- **Confirmed locally:** The existing Host application was detached from its DriverKit dependency and its standalone macOS target built successfully with Xcode 27.2. The corresponding project-file change is not yet published on the main branch.
- **Confirmed:** The legacy Mavericks driver and Linux Mbox 2 boot quirk have been examined. Their startup request sequences are not yet reconciled.

### Not demonstrated

- The device-specific firmware/device initialisation sequence on modern macOS.
- The expected all-LEDs-on state.
- USB audio endpoint transfers or streaming.
- Working Core Audio input and output.
- Operation in Universal Audio LUNA.

Audio MIDI Setup visibility, descriptor reads and a successful application build are not evidence of working audio.

## Non-negotiable security boundary

The primary Mac must keep **SIP enabled and normal Startup Security unchanged**.

The project will not use kernel extensions, Reduced Security, Recovery-mode changes, root-only USB access, forced USB capture, device-seize fallbacks, or termination of Apple's existing USB audio clients to obtain device ownership.

USB experiments must use ordinary, non-forcing access. If the required interface is already owned and normal access is denied, stop and record the result. Do not escalate.

## Selected architecture — Eleven Rack-style user-space implementation

This is the sole active implementation path. Do not develop a DriverKit or kernel-extension fallback.

The implementation is based on ordinary user-space USB communication, a transport-independent Mbox 2 protocol layer, and a Core Audio integration layer. The intended separation is:

- **USB transport/helper:** ordinary app-level USB access for the Mbox 2 protocol and device I/O.
- **Protocol core:** transport-independent request construction, response parsing and device state.
- **Core Audio integration:** publish a usable input/output device and bridge audio safely between the USB engine and Core Audio.
- **Configuration utility:** expose connection, device state and supported settings without taking ownership by force.

The precise helper/plug-in process boundary, Audio Server Plug-in lifecycle, signing and packaging requirements must be validated against the target macOS SDK. Do not claim those details are solved merely because the USB API experiment succeeded.

### Security boundary

- Keep SIP and normal Startup Security unchanged.
- Use ordinary, non-forcing USB access only.
- No DriverKit/kernel-extension fallback.
- No device seize/capture, root-only takeover, or termination of Apple's USB audio services.
- If normal access to a required interface is denied, stop and record the limitation. Do not escalate.

### Transport-independent protocol core

The protocol core must remain independent of the USB transport. The Mavericks driver contains a one-byte firmware handshake using request `0x85`; the Linux Mbox 2 quirk uses a different 18-byte boot-status request. Their relationship and ordering remain unresolved. Do not merge the two sequences by assumption.

## Next development stages

### Stage 1 — First bidirectional USB communication and device initialisation (LED milestone)

This is the immediate next milestone. Discovery, Audio MIDI Setup visibility, descriptor reading and ordinary interface-6 attachment are already demonstrated; do not repeat them.

- Continue only the specific static analysis needed to reconcile the Mavericks and Linux startup paths, including the unresolved five-stage `DigiHandshake::Do` helpers.
- Reconcile the different handshake/status requests, their parameters, order, expected responses and retry behaviour.
- Identify the complete initialisation sequence required to bring the Mbox 2 into its operational state.
- Document each request and the evidence supporting it.
- Do not send a firmware/vendor-specific or state-changing request until the sequence is reconciled, the exact test is justified, and the user explicitly approves it.
- Success criterion: the device initialises and all expected Mbox 2 LEDs illuminate, with no forced interface capture or security reduction.

### Stage 2 — Core Audio input/output (after the LED milestone)

After device initialisation is demonstrated:

- Integrate the proven ordinary USB access into the standalone user-space application architecture.
- Establish the supported Core Audio device-publication path.
- Implement playback and capture, initially testing each direction independently.
- Establish reliable buffering, timing and error handling.
- Confirm genuine two-way audio I/O through macOS, not merely appearance in Audio MIDI Setup.
- Do not claim success until real audio has been played and captured.

### Stage 3 — Universal Audio LUNA validation

After Core Audio input and output both work:

- Select the Mbox 2 as LUNA's audio device.
- Verify playback and recording.
- Then validate supported sample formats, 44.1/48 kHz rates and internal/external clock behaviour as evidence permits.

### Stage 4 — Complete the configuration utility

The native macOS utility should eventually:
- Show whether the Mbox 2 is detected, initialised and communicating.
- Show clock source and lock state only when measured reliably.
- Expose supported sample-rate and format settings.
- Remain focused on essential device configuration.

## Later investigations

Other Mbox-family devices and unrelated audio interfaces are outside the initial target. They should not distract from the original full-size Mbox 2.

## Completion criteria

A stage is complete only when its claims are backed by recorded evidence. Builds, packages, unit tests and device detection are useful milestones, but none independently proves successful firmware initialisation or working audio input and output.

### 19 November 2026 — ordinary USB interface access and control-transfer milestone

- **Confirmed on hardware:** The M1 Pro MacBook Pro enumerated the original Mbox 2 IOUSBHostInterface services and found interface 6 using registry properties for VID 0x0dba, PID 0x3000, and interface number 6.
- **Confirmed on hardware:** An IOUSBHostInterface object for interface 6 was created with ordinary IOUSBHostObjectInitOptionsNone access, then destroyed and released successfully.
- **Confirmed on hardware:** Through that interface object, one standard, read-only USB GET_DESCRIPTOR device-descriptor request completed successfully. All 18 requested bytes were transferred and the returned descriptor identified VID 0x0dba, PID 0x3000, device revision 0x0138.
- **Important boundary:** This proves ordinary interface access and one successful USB control transfer. It does **not** prove firmware initialisation, device/engine activation, LED control, audio streaming, Core Audio publication, or audio input/output.
- **Not attempted:** No seize/capture operation, configuration change, alternate-setting change, pipe creation, endpoint transfer, firmware handshake, sample-rate request, or audio streaming operation was performed.
- **LED expectation:** A standard device-descriptor read does not request hardware initialisation or an LED-state change. No LED response is expected from this test. The physical LED state after the descriptor request was not recorded as part of the transfer output.

See [the 19 November USB control-transfer session record](../research/usb-control-transfer-session-2026-11-19.md) for the request fields, exact returned bytes, parsing, cleanup, and limitations.


### 19 November 2026 — configuration descriptor cross-check

- **Confirmed on hardware:** A second standard, read-only GET_DESCRIPTOR request returned the 9-byte configuration header: `09 02 86 02 07 01 00 80 FA`.
- **Confirmed on hardware:** The header reports a total configuration length of **646 bytes**, seven interfaces, configuration value 1, bus-powered attributes, and 500 mA maximum power.
- **Strong cross-check:** The 646-byte total exactly matches the configuration-length prerequisite used by the Linux Mbox 2 boot quirk. This supports the conclusion that the Linux quirk recognises this hardware configuration.
- **Important limitation:** The matching length does not prove that the Linux boot-status request or its subsequent initialisation steps are interchangeable with the Mavericks driver sequence, nor does it authorise sending either request.
- **Not attempted:** No full configuration read, configuration selection/change, alternate-setting change, firmware/vendor request, endpoint transfer, sample-rate request, or audio operation.
- **Next:** Continue static comparison of the two startup paths before proposing any further hardware request.

The exact request, returned bytes, parsing, and safety boundaries are recorded in [the 19 November USB control-transfer session record](../research/usb-control-transfer-session-2026-11-19.md).


### 19 November 2026 — complete configuration descriptor parsed

- **Confirmed on hardware:** A standard read-only GET_DESCRIPTOR request returned the full 646-byte configuration descriptor through ordinary IOUSBHost access to interface 6.
- **Confirmed:** Offline parsing identified seven interfaces, their alternate settings, and all endpoint addresses, directions, transfer types and maximum packet sizes. The detailed map is in [the USB control-transfer session record](../research/usb-control-transfer-session-2026-11-19.md).
- **Confirmed from descriptors:** The PCM AudioStreaming paths advertise Type I, two-channel, 24-bit samples in three-byte subframes, with a continuous 8–48 kHz range.
- **Strong cross-check:** Interface 6 endpoints `0x02` OUT and `0x81` IN match the MIDI endpoints used by the Linux quirk. Endpoint `0x82` IN remains unexplained.
- **Important caution:** Interface 0 has a DFU-related class/subclass identifier, but the seven-byte class-specific descriptor is not enough to claim a standard operational DFU interface.
- **Not attempted:** No endpoint pipe or endpoint transfer, alternate-setting change, firmware request, USB reset, sample-rate operation or audio streaming was performed.


### 21 November 2026 — standalone Host build and next-session boundary

- **Confirmed locally:** The existing `Mbox2DriverHost` macOS application target was detached from its DriverKit target dependency and System Extensions embedding phase.
- **Confirmed locally:** `plutil -lint` passed for the edited Xcode project file, the DriverKit target remained separate, and the Host target built successfully with Xcode 27.2 using `xcodebuild -target Mbox2DriverHost`.
- **Important boundary:** This was a standalone application build. It did not integrate or re-run the already demonstrated USB discovery/interface-6 code, and it did not initialise the Mbox 2.
- **Next:** Resume at Stage 1 above: reconcile and document the device initialisation sequence required for the all-LEDs-on milestone. Do not restart USB enumeration, Audio MIDI Setup visibility, descriptor reading or interface-6 attachment.

See [Implementation foundation — 21 November 2026](implementation-foundation-2026-11-21.md) for the concise session handover.


### 22 November 2026 — user-space architecture reaffirmed and startup evidence updated

- **Decision reaffirmed:** The Eleven Rack-style user-space approach is the sole active architecture: ordinary user-space USB communication, a transport-independent Mbox 2 protocol core, a Core Audio integration component, and shared-memory audio transport where appropriate.
- **Parked:** DriverKit is not to be developed, investigated further, or treated as a fallback unless the project owner explicitly reopens the decision.
- **External project review:** The public [Eleven Rack Linux driver](https://github.com/kdbo/Elevenrack-driver-linux) README describes an ALSA `snd-usb-audio` compatibility patch that reuses the Linux audio/MIDI/mixer stack and documents implicit-feedback stream synchronisation. This is useful architectural reference only; its Linux code and ALSA mechanisms are not to be transplanted into the macOS project. The two visible pull requests (#1 and #2) are closed; GitHub reports no issue-thread comments or submitted reviews on either.
- **Confirmed from existing Mavericks disassembly notes:** `FirmwareHandshake(false)` uses request `0xC0/0x85`, `wValue=1`, `wIndex=1`, `wLength=1`; response byte `0x01` triggers a 300 ms retry delay, up to 30 retries after the initial request.
- **Confirmed from existing disassembly notes:** The relevant `initHardware()` branch attempts interface rematching for interface numbers 0 and 6, performs the one-byte handshake, and then calls the concrete `RayDevice::CreateAudioEngines()` override on the successful path. Static analysis does not establish the runtime outcome of those rematches.
- **Confirmed distinction:** The Linux boot quirk's 18-byte `0xC0/0x85` exchange (`wIndex=0`) is not interchangeable with the Mavericks one-byte request.
- **Open:** The separate five-stage `DigiHandshake::Do` routine remains unmapped. The planned short grep review was not completed in this session.
- **Not attempted:** No vendor-specific or state-changing USB request, endpoint transfer, configuration/alternate-setting change, firmware initialisation or LED test was performed.
- **Immediate milestone:** First justified and explicitly approved bidirectional USB communication sufficient to initialise the Mbox 2 and illuminate its expected LEDs.
- **Following milestone:** Working Core Audio playback and capture, followed by LUNA validation.
