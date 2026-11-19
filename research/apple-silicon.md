# Apple Silicon research

## Target system

The primary modern test target recorded for this project is:

| Item | Recorded value |
|---|---|
| Mac model identifier | `MacBookPro18,3` |
| Processor | Apple M1 Pro |
| macOS version | `27.0.1` |
| macOS build | `26A434` |
| Architecture | `arm64` |
| CPU cores | 8 total (6 performance, 2 efficiency) |
| Memory | 16 GB |

The user has designated the current target macOS release as **Golden Gate** for this project.

## USB detection

With the Mbox 2 connected, macOS identifies the USB device as **Digidesign Mbox 2**.

Recorded USB identifiers and properties:

| Property | Value |
|---|---|
| Vendor ID | `0x0dba` (decimal 3514) |
| Product ID | `0x3000` (decimal 12288) |
| USB speed | 12 Mb/s (Full Speed) |
| User authorisation | Authorised |

System logs showed Apple USB audio components, including `AppleUSBAudio` and `usbaudiod`, associated with ownership of USB interfaces.

## What is confirmed

- The USB system can detect and identify the connected Mbox 2.
- The reported vendor and product identifiers match the recorded Mbox 2 identifiers.
- The device is operating at USB Full Speed (12 Mb/s).

## What this does not prove

USB detection is only the first step. It does not prove that:

- The original firmware initialisation handshake has completed.
- The device is in the correct operating state.
- All required USB interfaces and endpoints are available to a replacement driver.
- CoreAudio can open the device successfully.
- Audio input or output streams correctly.
- Sample-rate changes or S/PDIF clock synchronisation work.

The presence of Apple USB audio components in logs should not be treated as proof that the Mbox 2 is fully supported by the modern operating system.

## Next investigation

Compare the USB descriptors and interface layout on the Mavericks reference system and the Apple Silicon target. Then determine which component claims each interface and whether the original device-specific initialisation sequence has taken place.

## 18 November 2026 — application-level detection

During a hardware check on the M1 Pro target Mac, the mBox 2 Control application reported the connected Mbox 2 as **Detected**.

The physical indicator state did not change during this check: the USB indicator remained off and the mono indicator remained on. This is a direct observation only; it does not identify the cause or establish which device-initialisation stage has completed.

A USB-B to USB-C cable has been located for a later connection test. It has not yet been tested. The planned test and its acceptance observations are recorded in [Mbox 2 hardware detection session — 18 November 2026](hardware-detection-session-2026-11-18.md).

Application-level detection is not proof of a completed firmware handshake, configured audio engine, or working audio input/output.

## 19 November 2026 — interface 6 endpoint descriptor query

On the M1 Pro target, a read-only diagnostic created the IOUSBLib plug-in for vendor-specific interface 6 and successfully queried `IOUSBInterfaceInterface190`. `GetEndpointProperties` returned three descriptors at alternate setting 0: endpoint 1 IN (interrupt, 16-byte maximum packet, interval 1), and endpoint 2 in both OUT and IN directions (bulk, 16-byte maximum packet). The query did not open the interface, change its alternate setting, issue a control request, or transfer endpoint data.

This confirms that modern macOS can expose these interface 6 endpoint descriptors through the legacy IOUSBLib interface. It does not prove that ordinary interface open/claim or any USB communication will succeed. The likely command/response and status roles of the endpoints remain hypotheses. Full method, output and limitations are recorded in [Modern macOS interface 6 endpoint discovery — 19 November 2026](modern-macos-interface-6-endpoint-discovery-2026-11-19.md).

## 12 November 2026 — modern macOS USB audio observations

A separate read-only test was performed on the user's work MacBook Pro, a 16-inch model with Apple M1 Max and 32 GB RAM, running a current macOS release (Tahoe). The exact macOS version and build were not recorded. These results are documented separately from the M1 Pro target-system inventory above.

The USB host reported the expected Digidesign identity (`0x0dba:0x3000`), device revision `0x0138`, USB 1.1, configuration 1 active and a 500 mA power allocation. Instantiated USB interface objects included Audio Control interface 1 and Audio Streaming interfaces 2–5, with `usbaudiod` client objects attached. The current interface objects all showed alternate setting 0; this query did not provide the complete descriptor set or prove that other alternate settings are absent.

At the user-facing audio layer, Audio MIDI Setup listed Mbox 2 but reported “no valid formats available”; System Settings > Sound did not offer it as an input or output. System Profiler listed it as a USB audio device and showed 48,000 Hz, but no input/output channel counts. Treat that rate as a reported property, not proof of an operational 48 kHz stream. No matching `AppleUSBAudioEngine` object was found in the queried registry view. A 15-minute `usbaudiod` log filter showed only a routine CoreAnalytics update and no Mbox-specific diagnostic message.

These observations establish detection without usable user-facing audio formats; they do not identify the failed initialisation stage or prove that the legacy firmware handshake failed. See [Modern macOS USB audio observations (12 November 2026)](modern-macos-usb-audio-observations-2026-11-12.md) for the interface listing, exact evidence limits and reproduction notes.
