# Development roadmap

This roadmap records the current evidence and the intended sequence of work. A planned milestone is not complete until its result has been demonstrated and documented.

## Evidence labels

Use these labels consistently:

- **Confirmed** — directly supported by repeatable observation, source code, or reliable documentation.
- **Strong indication** — supported by evidence, but an important part remains unverified.
- **Hypothesis** — a plausible explanation that needs testing.
- **Open question** — not yet answered by available evidence.
- **Not tested** — no test has yet been performed.

## Current status — November 2026

The project is in **research and early implementation**, not yet at a working-driver stage.

### Completed and evidenced foundations

- **Confirmed:** The original full-size Mbox 2 is identified as USB VID `0x0dba`, PID `0x3000`.
- **Confirmed:** The original driver and relevant firmware-handshake code have been examined on the working Mavericks reference system.
- **Confirmed:** The earlier minimal DriverKit extension and host-app scaffold compiled and packaged on Apple Silicon using Xcode 27.2. The source is now published under `Driver/`, `Host/` and `Mbox2Driver.xcodeproj/`; the latest interface-6-only matching refinement still requires a fresh build.
- **Confirmed:** A transport-independent C++17 protocol module was built and its unit tests passed in a clean Linux container.
- **Confirmed:** Modern macOS has existing `usbaudiod` clients attached to several Mbox 2 USB interfaces, creating an interface-ownership question for any replacement transport.
- **Confirmed:** A separate read-only IOUSBLib `IOUSBInterfaceInterface190` query returned interface 6 endpoint descriptors `0x81` interrupt IN, `0x02` bulk OUT and `0x82` bulk IN. The query did not open the interface or transfer endpoint data; see [19 November interface 6 endpoint discovery](../research/modern-macos-interface-6-endpoint-discovery-2026-11-19.md).

For the detailed build/package evidence and explicit limitations, see [DriverKit scaffold status](driverkit-scaffold-status.md). The proposed secure activation gate is documented separately in [DriverKit prototype preparation](driverkit-prototype-preparation.md).

### Not demonstrated

- DriverKit signing with the required entitlements, installation, activation or runtime loading.
- Successful device matching or ownership by the new implementation.
- Firmware initialisation on modern macOS.
- USB audio transfers, Core Audio device publication, capture or playback.
- 16-bit/24-bit operation, 44.1/48 kHz switching, or internal/external S/PDIF clock behaviour in a new driver.

A successful compile, package, unit test or USB enumeration is not evidence of working audio.

## Non-negotiable security boundary

The primary Mac must keep **SIP enabled and normal Startup Security unchanged**.

The project will not use kernel extensions, Reduced Security, Recovery-mode changes, root-only USB access, forced USB capture, device-seize fallbacks, or termination of Apple's existing USB audio clients to obtain device ownership.

USB experiments must use ordinary, non-forcing access. If the required interface is already owned and normal access is denied, stop and record the result. Do not escalate.

## Candidate architecture investigation

Current Apple documentation identifies two viable families of design, but neither is yet proven on this device.

### 1. USBDriverKit + AudioDriverKit — direct physical audio driver

This is Apple's current integrated architecture for a physical audio device:

- USBDriverKit provides the system-extension USB device/interface/pipe transport.
- The Mbox 2 protocol layer handles its vendor requests, stream configuration, clocking and packet behaviour.
- AudioDriverKit publishes the physical audio device and streams directly to the Core Audio HAL.

AudioDriverKit handles the HAL user-client communication, so a separate Audio Server Plug-in is not required. Current Apple platform research and unresolved entitlement/signing requirements are being documented separately; see the draft research pull request linked from the project repository.

**Gate:** the required DriverKit, USB transport and AudioDriverKit entitlements, provisioning/signing, activation with SIP enabled, and safe interface matching/ownership must be established. The existing DriverKit scaffold compiling is not proof that the extension can be activated. The ad-hoc sample path that requires SIP to be disabled is excluded.

### 2. App-process IOUSBHost + Audio Server Plug-in — alternative user-space route

Apple's IOUSBHost framework supports host-mode USB communication from apps, including custom and non-class-compliant devices. The 19 November hardware test proves that an `IOUSBHostInterface` object for Mbox 2 interface 6 can be initialised using ordinary IOUSBHost options and can return standard descriptors.

This is a useful basis for the immediate read-only discovery implementation. A separate Audio Server Plug-in could potentially publish a Core Audio device while an app-process USB engine performs I/O, but the complete lifecycle, permission model, isochronous streaming behaviour, latency and coexistence with Apple's USB audio clients remain unproven.

This route must not use any seize/capture fallback. If ordinary access to a required interface is denied, stop and record the result.

### 3. Transport-independent protocol core

The C++ protocol module remains independent of the eventual USB transport. It records the Mavericks one-byte handshake separately from the Linux 18-byte boot-status request. The relationship between those exchanges remains unresolved.

Keep the protocol core transport-neutral and expand it only when new behaviour is supported by evidence.

### Immediate first-pass target

Proceed with a read-only IOUSBHost discovery and descriptor-inspection module in the existing macOS utility:

- Match only the original full-size Mbox 2 VID/PID.
- Enumerate interfaces and report their class, subclass, protocol and alternate settings.
- Parse the captured 646-byte configuration descriptor into a structured endpoint map.
- Read standard descriptors through ordinary access only.
- Release interface objects cleanly and report access failures without trying to take ownership by force.

Do not send vendor-specific requests, change configurations or alternate settings, create endpoint pipes, or start endpoint transfers in this first pass.

## Next development stages

### Stage 1 — Build read-only discovery and descriptor parsing

- **Completed read-only substep:** IOUSBLib endpoint-descriptor discovery for interface 6 returned `0x81` interrupt IN, `0x02` bulk OUT and `0x82` bulk IN. This is descriptor inspection only; it does not demonstrate interface open/claim or endpoint communication.
- Implement the IOUSBHost device/interface inventory using the successful 19 November access path.
- Add a parser for the captured 646-byte configuration descriptor and test it offline using the saved descriptor as a fixture.
- Display the original device identity and the interface/alternate-setting/endpoint map.
- Keep USB access ordinary and non-forcing; do not attempt to open interfaces already held by Apple's audio services.
- Stop if access to a required interface is denied.

### Stage 2 — Resolve safe production transport and complete the protocol model

- Continue mapping the original driver's startup and firmware initialisation sequence.
- Determine the relationship between the Mavericks and Linux handshake exchanges.
- Resolve the clock-source and alternate-setting mappings.
- Establish endpoint and stream-control behaviour from source or repeatable observation.
- Keep confirmed facts separate from hypotheses.

### Stage 3 — Prototype the selected transport

Only after the production transport and entitlement/ownership gates are resolved:
- Build the smallest transport proof using ordinary, non-forcing access.
- Begin with descriptor reads and other non-mutating operations.
- Do not implement or send either firmware handshake until the Linux and Mavericks sequences are reconciled, the exact request is justified, and the user separately approves the hardware test.
- Record exactly which interfaces and requests are used.
- Keep the protocol core reusable across candidate transports.

### Stage 4 — Build the Core Audio path

- Evaluate device and stream publication through the selected supported macOS audio API.
- Implement input and output independently.
- Verify buffer handling, sample formats and timing.
- Do not claim audio support until real capture and playback are demonstrated.

### Stage 5 — Validate device features

- Test 16-bit and 24-bit operation where supported.
- Test 44.1 kHz and 48 kHz operation.
- Investigate internal clocking and external S/PDIF synchronisation.
- Distinguish device communication from actual clock lock.
- Use Universal Audio LUNA as the initial DAW validation target once basic Core Audio operation is stable.

### Stage 6 — Complete the configuration utility

The native macOS utility should eventually:
- Show whether the Mbox 2 is detected and communicating.
- Show clock source and lock state only when those states can be measured reliably.
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
