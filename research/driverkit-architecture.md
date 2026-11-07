# Modern macOS driver architecture research

**Date:** 8 November 2026  
**Research environment:** macOS 26.3, Apple M1 Max, Xcode 26.3  
**SDK inspected:** DriverKit 25.2 SDK  
**Target device:** Original full-size Digidesign Mbox 2 (USB VID 0x0dba, PID 0x3000)  
**Status:** Public SDK/header inspection and source-code research; no driver build or hardware validation performed.

## Purpose

This note records the current macOS DriverKit feasibility investigation and the resulting division of responsibilities between USB transport and Core Audio publication. It also records the Linux Mbox 2 reference topology and initialisation sequence that can guide later protocol work.

The findings establish that the public SDK contains the required API families. They do **not** establish that a third-party DriverKit extension can claim this particular device, obtain all required entitlements, or stream audio successfully on the target macOS release.

## Executive conclusion

The most plausible modern architecture is:

1. **USB transport layer:** use USBDriverKit to match and communicate with the Mbox 2, select interfaces and alternate settings, manage endpoint pipes, and submit isochronous transfers.
2. **Mbox 2 protocol layer:** implement the device-specific firmware handshake, vendor control requests, clock selection and any feedback/packet handling. These details are not supplied as a ready-made Mbox 2 implementation by Apple.
3. **Audio publication layer:** use AudioDriverKit to publish an audio device and input/output streams to Core Audio, advertise supported formats and rates, and expose controls.
4. **Configuration utility:** later expose only controls and status values whose semantics have been established from the original driver and hardware.

This is a proposed separation of responsibilities, not a completed implementation.

## DriverKit SDK inspection

The inspected SDK was Xcode 26.3's DriverKit 25.2 SDK on an Apple Silicon Mac running macOS 26.3. The following public headers were examined.

### USBDriverKit

Relevant headers include:

- `IOUSBHostDevice.h`
- `IOUSBHostInterface.h`
- `IOUSBHostPipe.h`
- `AppleUSBDefinitions.h`
- `AppleUSBDescriptorParsing.h`

The device and interface APIs include configuration selection, interface access, device requests, interface alternate-setting selection and endpoint-pipe acquisition. The descriptor parser header provides helpers to walk a configuration's descriptors, find interface descriptors, find endpoint descriptors and walk associated descriptors:

- `IOUSBGetNextDescriptor()`
- `IOUSBGetNextDescriptorWithType()`
- `IOUSBGetNextAssociatedDescriptor()`
- `IOUSBGetNextAssociatedDescriptorWithType()`
- `IOUSBGetNextInterfaceAssociationDescriptor()`
- `IOUSBGetNextInterfaceDescriptor()`
- `IOUSBGetNextEndpointDescriptor()`

This means a driver can use Apple's descriptor structures and parsing helpers rather than implementing a general USB descriptor walker from scratch.

`IOUSBHostPipe` exposes endpoint descriptor retrieval and isochronous I/O. `IsochIO()` accepts a data-buffer memory descriptor, a frame-list memory descriptor, a first frame number and an asynchronous completion action. Each `IOUSBIsochronousFrame` records the requested and completed byte counts, status and timestamp.

**Alternate-setting lifecycle detail:** Apple's `IOUSBHostInterface::SelectAlternateSetting()` documentation states that pending I/O on that interface's pipes is aborted and open pipes are closed when the alternate setting changes. The implementation must therefore reacquire/open the relevant endpoint pipes after changing an alternate setting; it must not continue using stale pipe objects.

The Mbox 2 is Full Speed USB (12 Mb/s). High-Speed USB microframe assumptions and high-bandwidth endpoint multiplier interpretations must not be applied to it.

### AudioDriverKit

Relevant classes and methods inspected include:

- `IOUserAudioDevice`, which derives from `IOUserAudioClockDevice`.
- `IOUserAudioStream`, including stream direction, current/available stream formats, stream activation, I/O start/stop and configuration-change handling.
- `IOUserAudioClockDevice`, including current and available sample-rate APIs.
- Device configuration-change methods such as `PerformDeviceConfigurationChange()`.

AudioDriverKit provides the Core Audio-facing device, clock and stream model. The Mbox-specific USB protocol and packet transport remain a separate responsibility.

The SDK contains class identifiers for clock-source and data-source controls. The existence of those control types does not establish how the Mbox 2 reports external-clock presence or S/PDIF lock; those states still require protocol and hardware evidence.

### USB Audio Class definitions

A targeted search of the public USBDriverKit and AudioDriverKit header directories for common USB Audio Class identifiers and descriptor names found no matches. No separate USB Audio Class framework appeared in the inspected DriverKit framework list.

This is limited to the public headers inspected. It is not evidence that macOS has no internal USB audio implementation. For this project, however, there is no public Mbox-ready USB Audio Class protocol layer to rely on. The safe design assumption is to implement the Mbox 2-specific USB protocol ourselves and publish the resulting audio streams through AudioDriverKit.

## Linux reference: Mbox 2 USB topology

The Linux kernel's `sound/usb/quirks-table.h` contains an explicit entry for VID `0x0dba`, PID `0x3000`. It describes this topology:

| Function | Interface | Alternate setting | Endpoint | Linux format |
|---|---:|---:|---:|---|
| Playback | 2 | 2 | `0x03` OUT | 2-channel, packed 24-bit big-endian |
| Capture | 4 | 2 | `0x85` IN | 2-channel, packed 24-bit big-endian |
| MIDI | 6 | — | `0x02` OUT, `0x81` IN | MIDI |

Linux ignores interfaces 0, 1, 3 and 5 in this quirk entry. For the two audio streams, the entry advertises 48,000 Hz only.

**Evidence limit:** this is the topology and format that the Linux quirk configures. It is not proof that the hardware cannot support other rates or formats. The original Mavericks driver contains additional alternate-setting logic, and its 16/24-bit and 44.1/48 kHz behaviour must be resolved independently.

## Linux initialisation and control requests

The Linux implementation is in `sound/usb/quirks.c`.

### Boot-status exchange

The Linux boot quirk:

1. Checks that the active configuration descriptor's total length is 646 bytes.
2. Issues request `0x85` with request type `0xc0`, value `0x0001`, index `0x0000`, and an 18-byte response buffer.
3. Polls at 500 ms intervals, up to 10 attempts, looking for response byte 0 to change from `0x01` (loading) to `0x02` (ready).
4. Rereads the device descriptor and resets the USB configuration.
5. Calls the 48 kHz setup routine.

The 646-byte descriptor check is a Linux quirk guard; it should not be treated as a universal Mbox 2 identity test without checking other device revisions.

### 48 kHz setup routine

Linux sets the three-byte rate payload to:

```
80 BB 00
```

This is 48,000 in little-endian form. It then issues the following control-message argument tuples, in the order used by the Linux helper (request, request type, value, index, data length):

| Request | Request type | Value | Index | Data |
|---:|---:|---:|---:|---|
| `0x01` | `0x22` | `0x0100` | `0x0085` | 3-byte temporary buffer |
| `0x81` | `0xa2` | `0x0100` | `0x0085` | `80 BB 00` |
| `0x81` | `0xa2` | `0x0100` | `0x0086` | `80 BB 00` |
| `0x81` | `0xa2` | `0x0100` | `0x0003` | `80 BB 00` |

The first tuple uses a receive control pipe; the remaining three use a send control pipe in the Linux source. These values are recorded as the helper's arguments, not decoded semantic names. The exact purpose of each index and the meaning of the preliminary three-byte transfer remain unresolved. They must not be assigned to playback, capture, clock or another function without corroborating evidence.

### Difference from the Mavericks driver

The inspected Mavericks `FirmwareHandshake(bool)` routine uses the same request code and request type (`0x85` / `0xc0`) but a different shape: value is the Boolean argument plus one, index is `0x0001`, response length is one byte, and a response byte of `1` causes a 300 ms retry (up to 30 retries after the initial request).

Do not merge the Linux 18-byte boot-status exchange and the Mavericks one-byte handshake into a single assumed protocol. The differences may reflect separate stages, firmware revisions or different meanings; this remains an open question.

## Proposed implementation boundaries

### USB transport

Responsibilities:

- Match the target VID/PID and establish device ownership, subject to macOS matching and entitlement requirements.
- Read and validate configuration/interface/endpoint descriptors.
- Select the required interface alternate settings.
- Acquire and manage endpoint pipes.
- Submit and complete isochronous transfers with preallocated buffers and frame lists.
- Handle cancellation, device removal, alternate-setting changes and pipe recreation.

### Mbox 2 protocol

Responsibilities:

- Reproduce the correct firmware readiness sequence after the Linux and Mavericks variants have been reconciled.
- Issue the vendor-specific setup requests only after their roles and ordering are understood.
- Translate clock-source and format preferences into device operations.
- Determine whether any asynchronous feedback endpoint or device-specific packet framing is required.
- Report actual device/clock states without conflating USB communication with S/PDIF lock.

### AudioDriverKit

Responsibilities:

- Publish the device and its input/output streams.
- Advertise only formats and sample rates supported by evidence.
- Coordinate stream format and sample-rate changes with the USB/protocol layers.
- Implement the appropriate device/stream configuration-change lifecycle.
- Keep real-time transfer/completion paths bounded and free of avoidable allocation, blocking locks, filesystem or network work.

### Configuration utility

The utility should remain a small configuration/status application, not a mixer or DAW. It should distinguish at least:

- USB device detected / driver communication established.
- Firmware initialisation complete.
- Internal or external clock selection, once its semantics are proven.
- Actual external S/PDIF lock, only when a reliable hardware status can be read.
- Current sample rate and active stream state.

A generic DriverKit connection or a successful firmware handshake must not be displayed as S/PDIF lock.

## Feasibility and unresolved risks

**Confirmed from SDK inspection:**
- Public USBDriverKit headers expose device, interface, pipe, descriptor and isochronous-transfer APIs relevant to this design.
- Public AudioDriverKit headers expose device, clock-device, stream and format/configuration APIs relevant to Core Audio publication.
- Alternate-setting changes invalidate the existing pipe I/O state and require pipe lifecycle handling.

**Confirmed from Linux source:**
- Linux has a specific Mbox 2 quirk for VID/PID `0x0dba:0x3000`.
- The quirk documents the interface/endpoint topology, 24-bit 48 kHz configuration, boot-status exchange and setup-request sequence described above.

**Not established:**
- Whether the required third-party DriverKit USB transport entitlement can be obtained for this device/vendor.
- Whether macOS will allow the extension to claim the Mbox 2 interfaces currently associated with Apple's USB audio components.
- Whether the Linux and Mavericks initialisation sequences are compatible, sequential or firmware-version-specific.
- The semantics of all Linux control-request indices and all Mavericks clock-source values.
- The full alternate-setting record mapping, packet sizes, timing and feedback requirements.
- Actual 16-bit, 24-bit, 44.1 kHz, 48 kHz and S/PDIF behaviour on hardware.
- Whether the proposed design builds, loads or streams on the target macOS release.

No driver code has been implemented or tested as part of this research note.

## Recommended next steps

1. **When hardware is available:** capture the Mbox 2's descriptors before and after firmware initialisation and compare them with the Linux topology.
2. Reconcile the Linux 18-byte boot-status exchange with the Mavericks one-byte firmware handshake.
3. Decode all 12 Mavericks alternate-setting records and trace their fields into endpoint setup.
4. Establish the exact roles of the three rate-setup indices and the preliminary transfer.
5. Verify DriverKit matching, entitlement and interface-ownership feasibility before committing to a production implementation.
6. Build a minimal USB transport proof of concept before adding AudioDriverKit stream publication.

## References

- [Linux USB audio quirk table](https://github.com/torvalds/linux/blob/master/sound/usb/quirks-table.h) — Mbox 2 interface, alternate-setting, endpoint, MIDI and format entry.
- [Linux USB audio quirks](https://github.com/torvalds/linux/blob/master/sound/usb/quirks.c) — Mbox 2 boot-status exchange and 48 kHz setup sequence.
- [Existing firmware handshake research](firmware-handshake.md) — Mavericks request fields and comparison with Linux.
- [Existing Apple Silicon research](apple-silicon.md) — modern target device detection.
- [Existing driver architecture map](driver-architecture.md) — original driver components and lifecycle.
