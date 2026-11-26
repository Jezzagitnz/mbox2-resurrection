# Session record — 26 November 2026

**Project:** Original full-size Digidesign Mbox 2 (USB VID `0x0dba`, PID `0x3000`)  
**Development Mac:** Apple Silicon M1 Pro MacBook Pro  
**Target environment:** macOS 27.0.1, Xcode 27.2  
**Local implementation checkout:** `~/Documents/Mbox2/mbox2-userspace`  
**Local implementation branch:** `userspace-foundation`  
**Last known local implementation checkpoint:** `8f809b3` — `Establish working IOUSBLib interface 6 initialisation`  
**Documentation branch:** `docs/session-record-2026-11-26`

## Session outcome

The next small implementation step was added to the local user-space application: **read-only inspection of the USB pipes exposed by an already-open interface 6**.

The updated implementation compiled successfully with the existing Xcode project and scheme. This is a build confirmation only; this session did not perform a new hardware inspection or USB data transfer.

## Work completed

### 1. SDK API checked

The macOS 27.2 SDK's `IOUSBLib.h` was checked for the interface-pipe inspection methods:

- `GetNumEndpoints(void* self, UInt8* intfNumEndpoints)`
- `GetPipeProperties(void* self, UInt8 pipeRef, UInt8* direction, UInt8* number, UInt8* transferType, UInt16* maxPacketSize, UInt8* interval)`

The API documentation states that pipe references range from 1 through the endpoint count returned by `GetNumEndpoints`. Pipe reference 0 is the default control pipe and is not part of this interface endpoint enumeration.

### 2. Objective-C bridge extended

The existing IOUSBLib Objective-C bridge was extended with wrappers for:

- Reading the number of endpoint pipes on an open interface.
- Reading the properties of an individual pipe.

The wrappers call the corresponding `IOUSBInterfaceInterface500` methods. They expose the results to Swift without moving native IOUSBLib function-pointer calls into Swift.

### 3. Swift USB service extended

`Mbox2USBService.swift` was extended with:

- `Mbox2USBPipeInfo`, a model for the properties returned for each pipe.
- `inspectInterface6Pipes()`, which requires interface 6 to have been opened, obtains the endpoint count, and reads each pipe's properties.

The pipe information includes the pipe reference, direction, endpoint number, transfer type, maximum packet size and interval, together with display descriptions.

### 4. Build verification

The user ran the existing Debug build:

```bash
PROJECT="$HOME/Documents/Mbox2/mbox2-userspace"
cd "$PROJECT" || exit 1
xcodebuild -project Mbox2Control.xcodeproj -scheme Mbox2Control -configuration Debug build
```

**Result reported by the user: build successful.**

## Files changed in the local implementation work

The endpoint-inspection implementation touched these three files:

- `Mbox2Control/Mbox2Control-Bridging-Header.h` — declarations for the two pipe-inspection bridge functions.
- `Mbox2Control/Mbox2USBPluginBridge.m` — Objective-C implementations using `GetNumEndpoints` and `GetPipeProperties`.
- `Mbox2Control/Services/Mbox2USBService.swift` — pipe information model and read-only interface-6 inspection method.

These implementation changes were made in the local `userspace-foundation` checkout. At the time of this documentation update, GitHub did not have a branch named `userspace-foundation`; therefore this session record does **not** publish or imply publication of those source changes. The local implementation changes still need to be reconciled and published separately from the Mac.

## UI review and pause point

The current versions of these two files were displayed and reviewed:

- `Mbox2Control/Models/Mbox2Device.swift`
- `Mbox2Control/Views/ContentView.swift`

The existing UI has a hardware connection check, preview-only audio and clock controls, and a basic device diagnostics panel.

A follow-on UI change was proposed to let the user trigger pipe inspection after interface 6 is opened and display each pipe's properties. The user then asked to hold off. **Do not treat the proposed UI replacement as applied, built, or verified.** The current confirmed checkpoint is the successful build of the underlying bridge/service pipe-inspection capability.

When work resumes, first establish whether either proposed UI file was actually changed locally. Do not overwrite the user's files based on the proposed replacement without checking.

## What this milestone proves — and does not prove

**Confirmed:**

- The SDK methods for enumerating and reading IOUSBLib pipe properties were identified.
- The Objective-C bridge and Swift service changes compiled successfully.
- The inspection method is designed to read pipe properties only after interface 6 has been opened.

**Not demonstrated in this session:**

- A fresh hardware run of `GetNumEndpoints` or `GetPipeProperties`.
- The actual pipe list returned by the Mbox 2 at runtime.
- Any USB endpoint data transfer.
- Bidirectional USB communication, firmware/device initialisation, or the all-LEDs-on state.
- USB audio streaming, Core Audio playback/capture, or Universal Audio LUNA operation.
- Application UI integration of the pipe-inspection results.

Reading endpoint/pipe properties is descriptor/interface inspection; it is not evidence that a pipe can transfer data or that the device is communicating.

## Safety boundary observed

- No vendor-specific USB request was sent.
- No control or endpoint data transfer was sent.
- No firmware handshake, Linux boot-status request, configuration change, alternate-setting change, reset, or audio-stream operation was attempted.
- No interface seize/capture or forced ownership was attempted.
- No Apple USB service was terminated.
- No SIP or Startup Security setting was changed.
- DriverKit remains parked; the agreed user-space architecture remains the active route.

Any future vendor-specific or state-changing USB request still requires a prior explanation of its exact fields, expected response, risks, retry/timeout behaviour and stop conditions, followed by the user's explicit approval.

## Next step when resumed

The next software task is to integrate the existing read-only pipe-inspection method into the app UI, but only after checking the current local UI files. The eventual hardware check should be performed only when the user is ready to reconnect the Mbox 2. It should report the actual pipe properties and must not submit transfers.

After that, continue toward the already-agreed first major milestone: evidence-based device initialisation and genuine two-way USB communication, with no repeated enumeration/interface-opening investigations and no unapproved USB requests.
