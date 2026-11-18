# SIP-compatible user-space USB and Core Audio path

**Research date:** 18 November 2026  
**Target:** Original full-size Digidesign Mbox 2 (USB VID `0x0dba`, PID `0x3000`)  
**Target Mac:** Apple M1 Pro, macOS 27.0.1, Xcode 27.2  
**Status:** Architecture investigation; no IOUSBHost prototype or Audio Server plug-in has been built or tested.

## Non-negotiable security constraint

Development and eventual operation on the primary Mac must not require disabling System Integrity Protection (SIP), reducing Startup Security, or using an ad-hoc-signed DriverKit extension that depends on bypassing macOS security checks.

Do not use a kernel extension. Do not use `IOUSBHostObjectInitOptionsDeviceCapture`, root-only device capture, or any mechanism that forcibly terminates Apple's existing USB clients as a routine workaround.

If a proposed route requires one of those changes, stop and reassess rather than asking the user to weaken the machine's security.

## Executive finding

There is a credible second architecture worth testing before treating DriverKit entitlement approval as the only route:

1. A normal user-space helper process uses Apple's **IOUSBHost** framework to communicate with the Mbox 2.
2. A Core Audio **Audio Server Plug-in** publishes the Mbox 2 as an input/output device.
3. The plug-in communicates with the helper through a declared Mach service.
4. Audio data moves between the helper and plug-in through a bounded shared-memory ring buffer; control and status messages use a separate non-real-time channel.

Apple documents IOUSBHost as an application-level framework for accessing custom and non-class-compliant USB devices. It documents both isochronous USB transfers and Audio Server Plug-ins. This makes the architecture technically plausible without a DriverKit extension.

**This is not yet a proven replacement.** The major risk is USB interface ownership: the Mbox 2's Audio Control and Audio Streaming interfaces 1–5 were previously observed with `usbaudiod` clients attached. A normal IOUSBHost open establishes exclusive ownership of the relevant I/O Registry service and fails if another client already holds it exclusively. We must test whether the required interfaces can be opened without capture, root privileges or disrupting Apple's driver.

## Candidate A — USBDriverKit + AudioDriverKit

This remains the cleanest modern Apple-native driver architecture:

- USBDriverKit handles the custom USB protocol and endpoint transport.
- AudioDriverKit publishes the Core Audio device and streams.
- The existing host application activates and manages the system extension.

Apple's current documentation requires the DriverKit entitlement and USB transport entitlement, with a matching provisioning profile and System Extension capability on the host app. Properly granted entitlements and signing are the intended secure deployment route. Apple's documented ad-hoc development workaround involves disabling SIP-related validation checks; this project will not use that workaround.

The minimal DriverKit source scaffold and its recorded Xcode build/package result exist on the separate `driverkit-foundation` branch / PR #14. That is a source/build milestone only. It does not establish signing, entitlement approval, activation, device ownership or audio.

**Keep Candidate A alive** while entitlement eligibility is investigated, but do not make it the only architecture.

## Candidate B — IOUSBHost helper + Audio Server Plug-in

### USB transport

The app-level IOUSBHost framework exposes:

- `IOUSBHostDevice` for device matching, configuration, descriptors and device requests.
- `IOUSBHostInterface` for interface descriptors, alternate-setting selection and endpoint pipes.
- `IOUSBHostPipe` for control, bulk, interrupt and isochronous transfers.

This is important because the Mbox 2 is not a simple standard USB Audio Class device from the driver's perspective. Its vendor-specific startup requests and non-standard stream topology still need device-specific handling, but the user-space framework exposes the relevant categories of USB operation.

The API's normal initialisation path uses `IOUSBHostObjectInitOptionsNone`. It establishes exclusive ownership of the selected `io_service_t`; Apple's documentation says initialisation fails if the kernel device or interface is already open for exclusive access.

### Do not use device capture

Apple documents `IOUSBHostObjectInitOptionsDeviceCapture` as an option that terminates existing clients and drivers for the device and its interfaces. The caller must have either the `com.apple.vm.device-access` entitlement plus `IOServiceAuthorize` authorization, or root privileges.

That option is explicitly excluded from this project. It is not an acceptable way to take the Mbox away from `usbaudiod`, and it is not a workaround to pursue on the primary Mac.

### Existing interface-ownership risk

The 12 November 2026 read-only IORegistry observations recorded:

- Interface 1: Audio Control, with a `usbaudiod` client.
- Interfaces 2–5: Audio Streaming, each with a `usbaudiod` client.
- Interface 0: vendor-specific.
- Interface 6: vendor-specific, with three endpoints.

The Linux Mbox 2 quirk uses audio interfaces 2 and 4 for playback/capture and interface 6 for MIDI. The Mavericks driver research also identifies stream interfaces 2–5.

The observed `usbaudiod` clients make an exclusive-open conflict a real risk, not a theoretical footnote. However, an attached registry client is not itself proof that every interface is currently held open exclusively. A carefully scoped, read-only open test is needed to establish the actual result.

Possible first checks, in order:

1. Enumerate the device and capture the complete configuration descriptors without changing device state.
2. Attempt normal, non-capture access to the device object only if required for descriptor reads.
3. Attempt a normal open of a single interface that is not needed by Apple's audio path, if one can be identified safely.
4. Determine whether the required audio interfaces can be opened normally.
5. If an interface is busy, record the exact error and stop. Do not seize it, kill `usbaudiod`, reset the device, or change system security.

A failed open is a meaningful architecture result. It does not justify escalating to device capture.

### Core Audio publication

Apple still documents an Audio Server Plug-in API and a sample that publishes a functioning Core Audio device. Apple's documentation also describes how an Audio Server Plug-in can communicate with another process through a Mach service declared in the plug-in's `Info.plist`.

The proposed separation is:

- **USB helper:** owns IOUSBHost objects, handles device notifications, performs protocol operations and schedules USB transfers.
- **HAL plug-in:** publishes device/stream properties and services Core Audio's real-time I/O callbacks.
- **Shared audio ring:** carries PCM frames between helper and plug-in with preallocated memory and bounded, lock-free producer/consumer operations.
- **Control IPC:** handles start/stop, sample-rate changes, clock state, errors and configuration outside the real-time callback.
- **mBox 2 Control app:** later manages installation, status and user-facing settings; it is not placed in the audio callback path.

The plug-in runs in a restricted audio-server environment. It must not try to use client HAL APIs from inside the plug-in, and it should not directly own the USB device. The helper boundary avoids placing USB setup, blocking work or general IPC in the real-time audio callback.

This path is older than AudioDriverKit and has more moving parts. Apple still publishes the plug-in API and sample, but its installation, signing, helper launch model and behaviour on macOS 27 must be verified locally before committing to it.

## Comparison

| Question | DriverKit + AudioDriverKit | IOUSBHost + Audio Server Plug-in |
|---|---|---|
| USB protocol access | USBDriverKit | App-level IOUSBHost |
| Core Audio publication | AudioDriverKit | Audio Server Plug-in |
| Restricted DriverKit entitlements | Required | Not part of the proposed USB helper path |
| SIP reduction | Not intended with valid entitlements and normal signing; Apple's ad-hoc bypass is excluded | Not part of the documented architecture; local install/signing requirements still need checking |
| Interface ownership | DriverKit matching/claiming rules and Apple USB audio conflict need testing | Normal IOUSBHost open is exclusive; existing `usbaudiod` clients may block it |
| Audio real-time boundary | DriverKit audio I/O path | Plug-in plus shared ring and helper IPC |
| Main risk | Entitlement grant and service matching | Ability to open required interfaces without capture |

## Protocol work that can remain transport-independent

The Mbox-specific protocol should not depend on USBDriverKit or IOUSBHost types. Keep request construction, response parsing, state transitions and format/rate metadata in a small transport-independent module.

The evidence already supports keeping these operations distinct:

- Mavericks one-byte firmware handshake: request type `0xC0`, request `0x85`, value = Boolean argument + 1, index `1`, length `1`; retry when a successful response byte equals `1`, sleeping 300 ms, for up to 30 retries after the initial request.
- Linux 18-byte boot-status exchange: same request type/code, but value `1`, index `0`, length `18`; Linux polls at 500 ms intervals and interprets response byte 0 values `1` and `2` as loading and ready.

Do not combine these into one handshake or assume their order until the relationship is resolved. Endpoint sampling-frequency requests are a third, separate category. The confirmed explicit sample-rate table is 44.1 and 48 kHz; the clock-source enum values and S/PDIF-lock semantics remain unresolved.

A pure protocol module and automated tests can be developed without hardware and reused by either USB transport.

## Proposed decision gates

### Gate 1 — Source and SDK verification

On the M1 Pro, verify the IOUSBHost framework and headers in the installed macOS 27 SDK, including the exact Swift/Objective-C API signatures for device matching, interface open, descriptor access and asynchronous isochronous I/O. Verify the Audio Server Plug-in headers and sample build requirements. Do not guess at API signatures from older SDKs.

### Gate 2 — Read-only USB discovery

Build a small diagnostic helper that only enumerates the Mbox 2, reads its identity and captures the complete raw configuration descriptor. No vendor control requests, alternate-setting changes, resets or streaming.

### Gate 3 — Normal interface-open test

Attempt ordinary, non-capture IOUSBHost access to one interface at a time. Record the interface number, result, error domain/code and whether the service was already matched by Apple. Do not request root, device capture or SIP changes.

The critical result is whether interfaces required for the audio streams can be opened while leaving the system's normal security configuration untouched.

### Gate 4 — Transport-only proof

Only if normal access succeeds, implement a controlled transfer test. Begin with a known-safe request whose purpose and response are established. Keep the Linux boot-status exchange and Mavericks handshake separate. Do not start continuous isochronous streaming until descriptors, alternate settings, packet sizes and startup state have been reconciled.

### Gate 5 — Core Audio proof

Prototype the Audio Server Plug-in independently with a virtual/test source and sink first. Then connect it to a simulated helper/ring buffer. Only after both halves are stable should the plug-in be connected to the physical Mbox 2 transport.

## Current recommendation

Pursue both routes in parallel at the architecture level:

1. Retain the DriverKit scaffold as the Apple-native route, pending confirmation of entitlement eligibility and a normal signed deployment path.
2. Investigate IOUSBHost as the no-DriverKit-entitlement route, with interface exclusivity as the first hard technical gate.
3. Build protocol logic and tests independently of either transport.
4. Keep SIP enabled throughout. If neither architecture can access the Mbox 2 under normal macOS security, document that as a platform restriction rather than weakening the primary Mac.

## References

- Apple, [IOUSBHost](https://developer.apple.com/documentation/iousbhost) — application-level user-space USB access.
- Apple, [IOUSBHostInterface](https://developer.apple.com/documentation/iousbhost/iousbhostinterface) — interface access, alternate settings and endpoint pipes.
- Apple, [IOUSBHostPipe](https://developer.apple.com/documentation/iousbhost/iousbhostpipe) — including isochronous transfers.
- Apple, [IOUSBHostObject initialization](https://developer.apple.com/documentation/iousbhost/iousbhostobject/initwithioservice:options:queue:error:interesthandler:) — exclusive ownership and normal open behaviour.
- Apple, [IOUSBHost device capture option](https://developer.apple.com/documentation/iousbhost/iousbhostobjectinitoptions/devicecapture) — capture requirements and termination behaviour; excluded from this project.
- Apple, [Creating an Audio Server Driver Plug-in](https://developer.apple.com/documentation/coreaudio/creating-an-audio-server-driver-plug-in) — Core Audio publication.
- Apple, [Audio Server Plug-in Mach services](https://developer.apple.com/library/archive/qa/qa1811/_index.html) — communication with an external helper.
- Apple, [Requesting DriverKit entitlements](https://developer.apple.com/documentation/driverkit/requesting-entitlements-for-driverkit-development) — secure DriverKit signing and provisioning.
- Project, [Modern macOS USB audio observations](modern-macos-usb-audio-observations-2026-11-12.md).
- Project, [Modern DriverKit architecture](driverkit-architecture.md).
- Project, [Firmware handshake investigation](firmware-handshake.md).
- Project, [Sample-rate, clock and USB stream control](sample-rate-clock-control.md).
- Project, [Asynchronous input audio path](async-input-audio-path.md).
