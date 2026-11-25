# Session record — 25 November 2026

**Project:** Original full-size Digidesign Mbox 2 (USB VID `0x0dba`, PID `0x3000`)  
**Development Mac:** Apple Silicon M1 Pro MacBook Pro  
**Target:** macOS 27.0.1, Xcode 27.2  
**Active local branch:** `userspace-foundation`  
**Local implementation checkpoint:** `8f809b3` — `Establish working IOUSBLib interface 6 initialisation`  
**Repository publication status:** This session record is being published separately. The implementation commit above was confirmed locally but was not present on the GitHub remote branch when this record was prepared.

## Result

**Confirmed on hardware:** The mBox 2 Control application successfully reported:

> Mbox 2 interface 6 was successfully initialised.

This is a significant step beyond discovery or descriptor reading. The application now successfully obtains an IOUSBLib device interface, enumerates USB interfaces, identifies interface number 6, and opens that interface using ordinary non-seizing access.

It proves interface-6 open/initialisation through the selected IOUSBLib route. It does **not** prove the Mbox firmware handshake, complete device initialisation, all-LEDs-on state, endpoint transfers, USB audio streaming, Core Audio playback/capture, or LUNA operation.

## Implementation approach

The working implementation uses **legacy IOUSBLib from the app's user-space process**, with a small Objective-C bridge for native C interface-function-pointer calls and Swift for device discovery and matching.

The bridge is intentional: calling IOUSBLib interface function pointers directly from Swift had caused an `EXC_BAD_ACCESS` during `CreateInterfaceIterator`. Moving those calls into Objective-C resolved that failure and allowed interface 6 to be enumerated and opened successfully.

The route is consistent with the project's agreed Eleven Rack-style user-space architecture. It does not introduce DriverKit, a kernel extension, forced device capture, or a device-seize fallback.

### Relevant SDK/API findings

- The macOS 27.2 SDK provides `IOUSBDeviceInterface100` and `IOUSBInterfaceInterface500`.
- The interface user-client UUID used by the bridge is `2D9786C6-9EF3-11D4-AD51-000A27052861`.
- The device user-client UUID is `9DC7B780-9EC0-11D4-A54F-000A27052861`.
- The bridge uses the standard `IOCFPlugInInterface` plugin UUID `C244E858-109C-11D4-91D4-0050E4C6426F`.
- The app has App Sandbox enabled with the USB device entitlement.
- IOUSBHost object construction had previously failed at `IOServiceOpen` in this app's sandbox context. The successful IOUSBLib path is now the active implementation route.

These SDK and sandbox observations are evidence about the current development environment; they are not a claim that every later transfer type or Core Audio integration detail is solved.

## Files included in the local implementation checkpoint

The local commit `8f809b3` contains seven changed files:

- `Mbox2Control.xcodeproj/project.xcproj`
- `Mbox2Control/Mbox2Control-Bridging-Header.h`
- `Mbox2Control/Mbox2Control.entitlements`
- `Mbox2Control/Mbox2USBPluginBridge.m`
- `Mbox2Control/Models/Mbox2Device.swift`
- `Mbox2Control/Services/Mbox2USBService.swift`
- `Mbox2Control/Views/ContentView.swift`

The Objective-C bridge exposes narrowly scoped functions to create the IOUSBLib device interface, create the interface iterator, open/close the selected interface, and release the native interfaces. Swift performs VID/PID discovery and matches interface number 6. The connection check reports the result to the app UI.

The local checkpoint was committed on `userspace-foundation`; the working tree was clean after the commit. The remote did not contain a branch named `userspace-foundation` when this documentation was prepared, so the implementation source itself still needs to be published from the development Mac. This documentation PR must not be mistaken for publication of those seven source/project files.

## Build and launch verification

The app built successfully using Xcode 27.2 with the existing `Mbox2Control` scheme and Debug configuration. The build used a dedicated derived-data directory under `~/Documents/Mbox2/Mbox2-Diagnostics-Build`.

The app was launched from that build and the user manually selected **Check USB Connection**. The reported interface-6 initialisation success is the observed result.

## Safety and scope

- No vendor-specific USB request was sent.
- No firmware handshake or Linux boot-status request was sent.
- No sample-rate, clock, alternate-setting, configuration, reset, or endpoint operation was attempted.
- No interface seize/capture API was used.
- No Apple USB service was terminated.
- No SIP or Startup Security change was made.
- The separate local `driverkit-foundation` checkout contains unrelated dirty DriverKit experiments and was not touched.

## Next milestone — reconcile initialisation protocols

Resume with the existing reverse-engineering evidence. Compare, without sending either request:

1. The Mavericks driver's one-byte firmware handshake: `bmRequestType=0xC0`, `bRequest=0x85`, `wValue=bool+1`, `wIndex=1`, `wLength=1`; it expects byte value 1 and retries at approximately 300 ms intervals for up to roughly 30 attempts.
2. The Linux Mbox 2 boot-status request, which transfers 18 bytes.

Establish whether these requests belong to different startup stages, are alternative platform-specific checks, or have another relationship. Do not combine them or infer ordering without evidence.

Before any hardware vendor request is proposed, document its exact fields, expected response, retry/timeout behaviour, risks, and stop conditions, then obtain the user's explicit approval.

## Following milestones

1. Complete the evidence-based initialisation sequence and reach the expected all-LEDs-on state.
2. Implement and verify genuine Core Audio playback and capture independently.
3. Validate real recording and playback in Universal Audio LUNA.
4. Only after basic audio works, investigate 16/24-bit formats, 44.1/48 kHz rates, and internal/external S/PDIF clocking.

Audio MIDI Setup visibility, USB discovery, descriptor reads, successful interface opening, and successful compilation must remain distinct from proof of working audio.
