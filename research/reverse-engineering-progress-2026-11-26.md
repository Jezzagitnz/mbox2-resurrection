# Mbox 2 Resurrection — Reverse-Engineering Progress

**Date:** 26 November 2026  
**Project:** Mbox 2 Resurrection  
**Architecture:** User-space USB + Core Audio HAL  
**Status:** USB discovery and interface 6 access established; legacy audio-engine initialisation sequence under investigation.

---

## 1. Project direction

The agreed architecture is an Eleven Rack-style user-space USB implementation for the original Digidesign Mbox 2.

The intended components are:

1. User-space USB device discovery, communication and hardware initialisation.
2. Audio input/output transport.
3. A Core Audio HAL / AudioServerPlugIn component exposing actual input and output streams.
4. Validation with Universal Audio LUNA.

DriverKit is parked. SIP changes, kernel-extension installation and paid Apple Developer membership are not prerequisites for the current development approach.

The immediate priority is to reconstruct the original driver's initialisation and USB communication sequence, then implement the equivalent safely in user space.

## 2. Hardware and development environment

### Target hardware

- Original Digidesign Mbox 2 (standard model).
- USB vendor ID: `0x0DBA`.
- USB product ID: `0x3000`.
- USB version: 1.1, 12 Mb/sec.
- Reported maximum power: 500 mA.

### Modern development Mac

- Apple M1 Pro MacBook Pro.
- 16 GB memory.
- macOS 27.0.1.
- Xcode 27.2.

### Legacy reference system

- 2012 Mac mini.
- macOS Mavericks 10.9.5.
- Original Mbox 2 operates with the legacy Digidesign driver and is visible in System Preferences, Audio MIDI Setup and Pro Tools 10/11.

The legacy system provides the reference driver and working-hardware behaviour for reverse-engineering.

## 3. Modern application and repository

Local repository:

`~/Documents/Mbox2/mbox2-userspace`

Application project: `Mbox2Control`

Relevant files include:

- `Mbox2Control/Mbox2Control-Bridging-Header.h`
- `Mbox2Control/Mbox2USBPluginBridge.m`
- `Mbox2Control/Models/Mbox2Device.swift`
- `Mbox2Control/Services/Mbox2USBService.swift`
- `Mbox2Control/Views/ContentView.swift`

Build command:

```bash
xcodebuild -project Mbox2Control.xcodeproj \
  -scheme Mbox2Control \
  -configuration Debug build
```

GitHub repository:

`https://github.com/Jezzagitnz/mbox2-resurrection`

PR #29 is open and not merged:

**Implement user-space IOUSBLib interface 6 initialisation**

Commit: `11f2f30`

No source-code changes are required for the documentation update described in this record.

## 4. Confirmed modern USB progress

The following work has already been completed:

- Ordinary USB discovery.
- USB configuration and descriptor reading.
- Successful user-space IOUSBLib attachment and opening of interface 6.
- Read-only interface 6 pipe diagnostics.
- Read-only capture of the complete 646-byte configuration descriptor.

The application owns interface 6. This demonstrates that the user-space USB access foundation is working for that interface.

Interfaces 2, 4 and 5 could not be opened because macOS `usbaudiod` owns them. The returned status was:

`-536870203 (0xE00002C5)` — `kIOReturnExclusiveAccess`.

Do not kill `usbaudiod` or attempt to take ownership through disruptive system changes. A proper ownership strategy remains to be designed.

**Important distinction:** The device currently appears in Audio MIDI Setup, but it does not expose actual input/output audio streams. USB discovery and device visibility are not equivalent to a working audio driver.

## 5. USB interface and endpoint map

The configuration descriptor identifies the following layout:

| Interface | Function / observation |
| --- | --- |
| 0 | DFU-related class/subclass; exact role not fully established |
| 1 | Audio Control |
| 2 | AudioStreaming |
| 3 | AudioStreaming; includes an AC-3-related alternate setting |
| 4 | AudioStreaming |
| 5 | AudioStreaming |
| 6 | Vendor-specific / MIDI-related |

### Audio endpoints

| Interface | Alternate setting | Endpoint | Direction | Maximum packet |
| --- | ---: | --- | --- | ---: |
| 2 | 2/3 | `0x03` | OUT, isochronous | 296 bytes |
| 2 | 2/3 | `0x83` | IN, isochronous | 3 bytes |
| 3 | 2/3 | `0x04` | OUT, isochronous | 296 bytes |
| 3 | 2/3 | `0x84` | IN, isochronous | 3 bytes |
| 3 | 6 | `0x04` | OUT | 192 bytes |
| 4 | 2/3 | `0x85` | IN, isochronous | 296 bytes |
| 5 | 2/3 | `0x86` | IN, isochronous | 296 bytes |

The 3-byte IN endpoints associated with interfaces 2 and 3 are likely feedback endpoints. Their synchronization attributes and exact role still need confirmation.

Interface 6 has:

- `0x81`: IN interrupt, 16 bytes.
- `0x82`: IN bulk, 16 bytes.
- `0x02`: OUT bulk, 16 bytes.

The `0x02` OUT and `0x81` IN endpoints are mapped to MIDI in the Linux driver reference. Endpoint `0x82` is not currently considered part of the audio path.

### Audio format descriptor

The PCM descriptor indicates:

- Type I audio format.
- Two channels.
- Three-byte subframes.
- 24-bit samples.
- Continuous sample-rate range from 8 kHz to 48 kHz.

The legacy driver also contains 16-bit and 24-bit format paths.

## 6. Legacy driver recovered

The main legacy executable was recovered from the Mavericks system and copied to:

`/tmp/DigidesignMbox2`

It is a 64-bit x86_64 Mach-O kernel-extension executable.

The associated legacy extensions include:

- `DigidesignMbox2.kext`
- `DigidesignMbox2Boot.kext`

The main executable has been symbolised and disassembled. Relevant function addresses and recovered behaviour are recorded below.

### Important USB-device methods

| Function | Address |
| --- | ---: |
| `MaudioShDrRayUsbDevice::start` | `0x4d18` |
| `FirmwareHandshake` | `0x4fc6` |
| `CreateAudioEngines` (device stub) | `0x547a` |
| `RayDevice::CreateAudioEngines` | `0xc9ca` |
| `RayEngine::initHardware` | `0xb64c` |

`MaudioShDrRayUsbDevice::start` stores the USB device object at `this + 0xe0`.

The legacy `FirmwareHandshake` uses a vendor device-to-host request:

- `bmRequestType = 0xC0`
- `bRequest = 0x85`
- `wValue = bool + 1`
- `wIndex = 1`
- `wLength = 1`

It expects a one-byte response of `1`, retrying at approximately 300 ms intervals for up to around 30 attempts.

**This request has not been sent by the modern application.** It is a reverse-engineered operation only. Do not send it without first documenting its purpose, expected effects and recovery behaviour, then obtaining explicit approval.

## 7. Recovered stream-interface tables

The legacy binary contains two important static tables.

### `kStreamInterfaceE`

Address: `0x1dab0`  
Record size: 12 bytes  
Record count: 4

Recovered records:

```text
02 00 00 00 00 00 00 00 00 00 00 00
03 00 00 00 00 00 00 00 01 00 00 00
04 00 00 00 01 00 00 00 03 00 00 00
05 00 00 00 02 00 00 00 03 00 00 00
```

The first byte of each record identifies USB interfaces 2, 3, 4 and 5.

The remaining fields are used by the legacy engine's interface-selection logic. Their full meaning has not yet been established.

`kStreamInterfaceCount` is 4, at `0x1dae0`.

### `kAltInfoE`

Address: `0x1db30`  
Record size: 28 bytes  
Record count: 12

The table contains alternate-setting information for interfaces 2–5:

- One alternate-setting 0 record for each interface.
- Alternate-setting 2 and 3 records for each interface.

`kAltInfoCount` is 12, at `0x1dc80`.

The records contain values including:

- `0x01`
- Interface/setting-dependent values `0x03`, `0x04`, `0x05` and `0x06`
- `0x0000BB80`, which is decimal 48000
- `0x02` in byte 15 of the active alternate-setting records

The exact meanings of all 28-byte fields remain unresolved. The value 48000 is consistent with a sample rate, but the field interpretation must be confirmed by tracing its consumers rather than assuming it.

### `GetAlternateSettingInfo`

Address: `0x7dc4`

This method searches the 12 records using:

- Byte 0: interface number.
- Byte 1: alternate-setting number.

When it finds a match, it copies 28 bytes of information to the caller.

This establishes that the legacy driver uses a table-driven description of its stream interface alternate settings.

## 8. Alternate-setting selection and application

### `RayEngine::GetAlternateSetting`

Address: `0xc2d0`

The function:

1. Calls a preference-data virtual method at vtable offset `0x48`.
2. If that method returns true, selects alternate setting 6.
3. Otherwise calls `RayPrefData::GetClockSource()`.
4. If the clock-source result is 1, selects alternate setting 2.
5. Otherwise selects alternate setting 3.

The first preference method is believed to relate to AC-3 enablement, but this should be confirmed by identifying its implementation before treating that interpretation as final.

### `RayEngine::SetAlternateSetting`

Address: `0xc312`

The function iterates over the four stream-interface records.

It obtains the interface service for each mapped USB interface, checks whether that interface is enabled in preference data, and then calls the interface service's `SetAlternateSetting()` method.

Enabled interfaces receive the requested alternate setting. Disabled interfaces receive setting 0.

The table contains values at offset +8 of 0, 1, 3 and 3. Their exact role in the loop's mapping logic still needs to be established.

### Interface-service alternate-setting method

`MaudioShDrRayUsbInterfaceService::SetAlternateSetting` is at `0x445e`.

The method:

- Handles special values `0xFF` and `0xFE` separately.
- For ordinary settings, looks up the matching alternate-setting information.
- Compares fields in the returned information with fields stored in the service.
- If the values match, calls the underlying interface object's alternate-setting method.
- Otherwise takes an internal error/reconfiguration path.

The default failure status is `0xE00002BC`.

The underlying `MaudioShDrRayUsbInterface::SetAlternateInterface` is at `0x22a2`.

It releases an existing object held at `this + 0xc0`, checks the interface object at `this + 0x88`, and calls methods on the underlying interface object's vtable before and after requesting the alternate setting.

The exact IOUSBInterface ABI meanings of those virtual slots have not yet been positively identified.

**No alternate-setting changes have been made to the modern Mbox 2.**

## 9. Legacy USB engine initialisation

### `MaudioShDrRayUsbEngine::initHardware`

Address: `0x65e6`

The disassembly shows that this method:

1. Calls a superclass initialisation method through vtable offset `0x9f0`.
2. If successful, creates an `IOTimerEventSource` using `StartTimerProc`.
3. Stores the timer event source at `this + 0x170`.
4. Clears a field at `this + 0x160`.
5. Retrieves the work loop at `this + 0xc0`.
6. Adds the timer event source to that work loop through a virtual call at offset `0x140`.

This method establishes the engine's timer/work-loop infrastructure. It does not itself show the main USB hardware initialisation sequence.

### `RayEngine::initHardware`

Address: `0xb64c`

The Ray-specific initialisation method:

1. Calls a superclass engine method through vtable offset `0x9f0`.
2. Determines the Mbox model using the USB product ID and device type.
3. Sets the audio sample format byte order to Little Endian.
4. Calls a virtual method through vtable offset `0xcf0`.
5. If successful, calls `CreateStreams()`.
6. Performs additional virtual calls to configure and obtain stream objects.
7. Calls `CreateControls()`.
8. Performs final engine configuration calls.

The method uses stream objects held at `this + 0xe0` and `this + 0xd0`.

The call through vtable offset `0xcf0` is a particularly important unresolved target because it occurs before stream creation.

Relevant methods:

| Method | Address |
| --- | ---: |
| `RayEngine::initHardware` | `0xb64c` |
| `RayEngine::CreateStreams` | `0xb86a` |
| `RayEngine::CreateControls` | `0xba68` |

## 10. New finding: `CreateAudioInterfaceServices`

Address: `0x7b08`  
End: `0x7c49`

This routine is a significant discovery because it shows how the legacy USB engine creates and registers the four streaming-interface services.

### Reconstructed sequence

1. It retrieves an object from `this + 0x118`.
2. It calls a virtual method at offset `0x680` on that object.
3. The returned object is checked using `OSMetaClassBase::safeMetaCast`.
4. It reads `kStreamInterfaceCount`, which is 4.
5. It repeatedly calls a virtual method at offset `0x898` to retrieve USB interface objects.
6. For each returned interface object, it obtains the interface number through vtable offset `0x8b0`.
7. It compares that interface number against the first field of each 12-byte `kStreamInterfaceE` record.
8. When a match is found, it calls:

   `MaudioShDrRayUsbInterfaceService::withInterface(engine, IOUSBInterface*)`

9. If service creation succeeds, it registers the service with an engine-owned object at `this + 0x120`, through a virtual call at offset `0x1b8`.
10. It then releases its temporary reference to the newly created service.
11. It continues until all four table entries have been processed.

If an interface or service cannot be obtained, the routine returns `0xE00002BC`.

### What this confirms

- The legacy engine expects four streaming interfaces.
- It does not simply assume that an interface object is already available.
- It retrieves interface objects from a provider.
- It matches the retrieved interfaces against its static stream-interface table.
- It creates a dedicated `MaudioShDrRayUsbInterfaceService` for each matching interface.
- It registers each service with an engine-owned collection or manager.

This is an important part of the legacy architecture and provides a concrete reference for designing our user-space interface-management layer.

### What it does not yet establish

- The exact identity and implementation of the interface provider at `this + 0x118`.
- The exact meaning of the provider's virtual method at `0x680`.
- The exact meaning of its interface-retrieval method at `0x898`.
- The exact type and behaviour of the registration object at `this + 0x120`.
- Whether all four interfaces are always required for every operating mode.

These details should be traced before translating the design into modern USB operations.

## 11. Interface-service construction

`MaudioShDrRayUsbInterfaceService::withInterface` is at `0x4134`.

It:

- Allocates a service object.
- Initialises it with the engine and USB interface.
- Releases the object if initialisation fails.
- Returns the initialised service if successful.

`MaudioShDrRayUsbInterfaceService::init` is at `0x3ee2`.

It stores the engine and interface references, obtains the USB interface number through an interface-object virtual call, initialises service state, and asks the engine for alternate-setting information.

It also allocates a sample buffer.

`SampleBufferAllocate` at `0x400c` uses:

`IOBufferMemoryDescriptor::withCapacity(size, 3, 1)`

The allocated buffer address is obtained through a virtual call and stored by the service.

This shows that each interface service has its own buffer-management responsibilities.

### Related service methods

| Method | Address |
| --- | ---: |
| `Start` | `0x41a8` |
| `Stop` | `0x41ca` |
| `StopUsingEngine` | `0x41e8` |
| `FinalizeBuffers` | `0x420a` |
| `TransferAudio` | `0x4228` |
| `GetSampleBuffer` | `0x4284` |
| `GetSampleBufferSize` | `0x428e` |
| `WaitUntilStopped` | `0x42b8` |
| `SetBufferSize` | `0x42ce` |
| `SetLeadFrames` | `0x42f0` |
| `SetFormat` | `0x4306` |
| `PostFinalizeBuffersSetFormat` | `0x4328` |

These methods are promising targets for understanding how the legacy engine transitions from interface configuration to actual audio transport.

## 12. Existing audio transport findings

Previous disassembly work established that the legacy driver uses asynchronous USB audio transfers.

### Input

The legacy asynchronous input path uses:

- 200 frame-list entries.
- 400 descriptors.
- Two descriptors per read submission.
- 50 initial submissions.
- A callback that consumes completed data and resubmits transfers.
- A circular sample ring.

### Output

The legacy playback path uses:

- Four 16-byte descriptors per asynchronous write submission.
- Feedback data to manage packet sizing.
- Variable packet sizes using a fractional accumulator.

The exact feedback-data units and packet-size calculation still need to be resolved.

These findings are a foundation for reconstructing the transport, but they are not yet implemented in the modern application.

## 13. Safety and implementation boundaries

The following restrictions remain in force:

- Do not send vendor-specific firmware requests without explicit approval.
- Do not change USB alternate settings without explaining the exact operation and obtaining explicit approval.
- Do not initiate audio streaming or other potentially state-changing USB transfers without explicit approval.
- Do not reset the device or change its configuration without explicit approval.
- Do not kill `usbaudiod` or attempt to disrupt system audio ownership.
- Continue using read-only descriptor and binary analysis where possible.

The legacy driver disassembly is evidence of what the original driver did. It is not automatic permission to reproduce every operation on the connected device.

## 14. Outstanding questions

The most useful unresolved questions are:

1. What does the `RayEngine::initHardware` virtual call at `0xcf0` do?
2. What are the exact identities and methods of the interface provider and service-registration object used by `CreateAudioInterfaceServices`?
3. What do all fields in the 28-byte `kAltInfoE` records represent?
4. What are the exact meanings of the IOUSBInterface virtual calls involved in alternate-setting changes?
5. How are clock source and AC-3 preferences translated into interface configurations?
6. What is the exact sequence of operations required to initialise the device before starting audio?
7. How are asynchronous input and output transfers scheduled and how is feedback interpreted?
8. What is the safest modern user-space strategy for obtaining access to the audio interfaces currently owned by `usbaudiod`?

## 15. Recommended next investigation sequence

The next session should begin with documentation and repository housekeeping, not another broad search.

After the documentation is saved, continue in this order:

1. Identify the method called by `RayEngine::initHardware` at vtable offset `0xcf0`.
2. Identify the interface-provider methods used by `CreateAudioInterfaceServices`.
3. Trace the service registration and interface reacquisition paths.
4. Follow the service `Start`, `FinalizeBuffers` and `TransferAudio` methods.
5. Connect those methods to the asynchronous read/write implementations.
6. Reconstruct the full initialisation order before attempting any hardware-changing operation.
7. Design the modern user-space equivalent and its ownership strategy.

### Current milestone assessment

**Completed:** USB discovery, descriptor reading, interface 6 user-space access, legacy driver recovery, stream-interface table recovery, alternate-setting selection analysis, and initial reconstruction of legacy interface-service creation.

**In progress:** Reconstructing the legacy engine's interface acquisition and hardware initialisation sequence.

**Not yet completed:** Modern hardware initialisation, reliable two-way USB audio transport, Core Audio input/output streams, and LUNA validation.

The immediate objective remains to turn the recovered legacy sequence into a precise, safe implementation plan—not to repeat already completed USB discovery work.
