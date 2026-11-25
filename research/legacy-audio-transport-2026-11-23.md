# Legacy Mbox 2 audio transport — static analysis (23 November 2026)

## Scope and evidence

This note records static analysis of the original DigidesignMbox2.kext on the Mavericks reference Mac. It is not a record of live USB transfers or a modern-Mac audio test.

Evidence labels:
- **Confirmed by disassembly/symbols** means the operation, branch, data movement or named method is directly visible.
- **Strong indication** means the interpretation is supported by call shape and corroborating API structure, but the exact method or field meaning is not proven.
- **Open** means further call-site, ABI or descriptor correlation is required.

No vendor-specific request, configuration change, alternate-setting change, endpoint transfer, or audio transfer was sent during this session.

## 1. Audio-stream interface discovery

The legacy engine's kStreamInterfaceE table is at 0x1dab0. Its count is four (kStreamInterfaceCount at 0x1dae0), and the table occupies four 12-byte records.

Raw bytes, grouped by record:

| Record | Bytes |
|---|---|
| 1 | 02 00 00 00 00 00 00 00 00 00 00 00 |
| 2 | 03 00 00 00 00 00 00 00 01 00 00 00 |
| 3 | 04 00 00 00 01 00 00 00 03 00 00 00 |
| 4 | 05 00 00 00 01 00 00 00 02 00 00 00 |

CreateAudioInterfaceServices() at 0x7b08 enumerates USB interfaces using the device's FindNextInterface virtual method. For each candidate, it compares the returned interface number with the first byte of each table record. Matching interfaces are wrapped in MaudioShDrRayUsbInterfaceService objects and added to the engine's interface collection.

**Confirmed:** the four audio interface numbers are 2, 3, 4 and 5. These correspond to the four AudioStreaming interfaces already found in the Mbox 2 configuration descriptor.

**Open:** the meanings of the remaining eight bytes in each table record have not been established. They must not be labelled as direction, channel count, endpoint or alternate setting without tracing their consumers.

The separate kAltInfoE table begins at 0x1db30. GetAlternateSettingInfo() at 0x7dc4 scans 12 entries with a 28-byte stride. Each entry is keyed by its first two bytes (interface number and alternate-setting number); on a match, the routine copies 28 bytes to the caller's output structure.

**Confirmed:** table size, entry count, key fields and copy size.

**Open:** meanings of the remaining 26 bytes in each alternate-setting record.

## 2. Transfer implementation selection

MaudioShDrRayUsbInterfaceService::CreateAudioInterface() at 0x45b2 dispatches on a selector value from 3 through 6:

| Selector | Concrete class constructed |
|---:|---|
| 3 | AdaptiveRead |
| 4 | AdaptiveWrite |
| 5 | AsyncRead |
| 6 | AsyncWrite |

This is a direct mapping from the factory's jump table.

**Open:** the complete call-site chain that supplies each selector has not yet been traced, so this mapping does not by itself assign one of these four implementations to a particular Mbox 2 interface or endpoint.

The driver contains both adaptive and asynchronous read/write implementations, plus a separate AsyncFeedback class. Do not assume the Mbox 2 uses only the AsyncRead/AsyncWrite pair for every mode.

## 3. USB controller frame clock and coordinated start

The interface service's GetUsbFrameNumber() wrapper calls the underlying interface method. The interface method obtains its associated USB device, then its bus/controller, and calls the controller's frame-number method.

The path through USB interface -> device -> bus/controller -> GetFrameNumber() is strongly corroborated by Apple's IOUSBInterfaceUserClient source. The exact legacy vtable ABI should still be treated carefully.

RayEngine::GetUsbFrameNumberStart() at 0xbdcc calculates a target of current controller frame + 2. When its alignment argument is true, it rounds that target up to the next four-frame boundary.

RayEngine::performAudioEngineStart() obtains the current USB frame number and asks whether the stream is asynchronous. The asynchronous path uses the four-frame-aligned target. The engine then coordinates its streams against that target.

MaudioShDrRayUsbStream::Start() starts each active interface service, records the target frame, and creates WaitForStreamingStartThread(). The worker repeatedly reads the USB controller frame number and waits until the target frame is reached. If the target is already missed or is too far away (outside the observed 1–999 frame window), the worker marks the stream as failed.

StartStreams() iterates ready streams and coordinates their start using the common target frame.

**Engineering significance:** the legacy implementation uses the USB controller's frame clock for start alignment. This is not simply a timer started from the host application's wall clock.

## 4. Audio movement through the engine

TransferToOutputInterfaces() iterates the engine's interface services and selects services that are streaming and active. It obtains each service's channel count, calculates the corresponding source-buffer offset, and calls the service's TransferAudio() method.

TransferFromInputInterfaces() follows the corresponding capture path, selecting streaming/active services whose direction flag matches the input path, then calling TransferAudio().

The service TransferAudio() method is a dispatcher:
1. It checks that the underlying interface exists.
2. It checks the interface's active state through a virtual method.
3. It tail-calls the concrete interface implementation through another virtual slot.

It is not itself the USB pipe submission.

## 5. Low-latency isochronous frame-list submission

The legacy binary contains named methods and callbacks for IOUSBLowLatencyIsocFrame, including:
- AsyncRead::UsbFrameListInit(), UsbFrameListSubmit() and UsbFrameListHandler().
- AsyncWrite::UsbFrameListInit(), UsbFrameListSubmit() and UsbFrameListHandler().
- AdaptiveRead/AdaptiveWrite equivalents.
- AsyncFeedback::UsbFrameListSubmit() and UsbFrameListHandler().
- Shared allocation and completion helpers on MaudioShDrRayUsbInterface.

The AsyncRead submission routine at 0x3036:
- Reads the current USB controller frame number.
- Checks scheduling/buffer state.
- Builds a frame list with two entries (the disassembly initialises two 16-byte frame records).
- Submits the list through a virtual method on the USB interface object.
- Advances its frame-list schedule by two frames and updates its queued-list bookkeeping.

The AsyncWrite submission routine at 0xdcde:
- Validates its preallocated buffer, frame-list and feedback structures.
- Calls AsyncWrite::UsbFrameListInit() with a count of four and a FeedbackData structure.
- Uses a USB-frame-related virtual method to prepare/coordinate the list.
- Submits through a virtual method on the USB interface object.
- Advances its schedule by four frames and updates queued-list bookkeeping.

AsyncWrite::TransferAudio() calls TransferAudioPerform() and checks completed frames when the controller frame is sufficiently close to the queued schedule. AsyncRead also maintains frame-list and buffer-window state and has a separate completion handler.

**Confirmed:** low-latency isochronous frame structures, separate read/write frame-list paths, asynchronous completion callbacks, two-frame read submissions, four-frame write submissions, and write-side FeedbackData input.

**Open:** the exact USB interface virtual methods used for the low-latency submissions are not yet symbolically identified. The disassembly shows calls through interface-object vtable offsets (read path +0x1f8; write path +0x200 in the relevant call sites), but the nm symbol search did not reveal a named imported USB submission function. Do not label these offsets as a specific API method until the exact legacy interface vtable is resolved.

The symbol UsbPipeRetain(IOUSBPipe*) appears in AsyncFeedback, but that alone does not identify the read/write submission calls.

## 6. Implications for the Mbox 2 implementation

The legacy driver establishes a useful transport model:

- Use isochronous USB transfers for audio, not bulk transfers.
- Keep input and output paths distinct; they have different scheduling and frame-list construction.
- Maintain a queue of transfer buffers/frame lists and process asynchronous completions.
- Schedule against the USB controller's frame clock where the modern API permits it.
- Treat packet sizes, per-frame actual lengths, transfer status and buffer capacity as first-class state.
- Keep feedback handling explicit; do not assume the output path can be implemented correctly without understanding the Mbox 2's feedback mechanism.
- Keep interface discovery, alternate-setting metadata and transfer-class selection as separate concerns.

This is a transport design reference, not a code-port specification. The Mavericks kernel implementation's exact APIs and vtable ABI are not automatically available to an ordinary modern macOS process. The modern user-space transport must use supported APIs and preserve the project's ordinary-access/no-seize boundary.

The next implementation milestone remains device initialisation and the explicitly approved LED test. Audio endpoint transfers must not be attempted until the exact initialisation sequence, interface ownership and transfer API are established and the user has approved any state-changing test.

## 7. External Eleven Rack reference review

### Apple Silicon macOS project

Repository: https://github.com/Matt-Housley/eleven-rack-driver

Reviewed README, engine source, stream source, shared-ring header and Core Audio plug-in at the repository snapshot identified by commit 719fe18ea88857a1ef06f63190d6d9d762ae6f62 (27 August 2026).

- The project uses IOUSBLib IOUSBDeviceInterface500 / IOUSBInterfaceInterface500 and asynchronous isochronous calls named ReadIsochPipeAsync() and WriteIsochPipeAsync().
- Its engine opens the device with USBDeviceOpen(), then explicitly falls back to USBDeviceOpenSeize() on kIOReturnExclusiveAccess. It also sets configuration 1, opens interfaces, selects alternate settings and locates isochronous pipes.
- **Do not copy USBDeviceOpenSeize().** The Mbox 2 project forbids forced device takeover/seizing. If ordinary access is denied, stop and record the result.
- Its shared ring is version 7 with 32,768 frames. Capture uses a single-producer/single-consumer FIFO. Playback is time-addressed using Core Audio's output sample time; the plug-in calls er_out_write_at() using mOutputTime.mSampleTime, and the engine reads from a play head trailing the furthest written sample time. The ring also carries a hardware-frame counter.
- This is an important Core Audio lesson: do not assume a simple append-only playback FIFO will satisfy multi-client AudioServerPlugIn WriteMix scheduling. Mbox 2's shared transport must be designed against the actual Core Audio IO-cycle sample-time contract.
- The repository's playback-dropout analysis document still has a top-level status line saying the time-addressed fix is not implemented, while the current source contains the time-addressed output-ring implementation. Treat that status line as stale/inconsistent until the project owner confirms the release/validation state; do not repeat it as a current source-code fact.
- The repository's README identifies version 1.1.0. The two open issues remain: #1 reports recovery problems after endpoint 0x83 transaction errors; #2 is our question about USBDeviceOpenSeize, SIP and signing. Neither issue has a maintainer reply or comments. No public pull request was found in the checked repository snapshot.

### Linux Eleven Rack project

Repository: https://github.com/kdbo/Elevenrack-driver-linux

This is a secondary Linux/ALSA reference, not the macOS architecture to port. It patches the existing Linux snd-usb-audio kernel driver for Eleven Rack USB ID 0dba:b011. The README describes capture endpoint 0x83 on interface 4 as implicit feedback for playback.

The merged PR #1, “Fix/implicit feedback packet capacity” (merged 16 October 2026), has no PR comments or review submissions. Its current documentation records later investigation through 20 October:
- It bounds implicit-feedback descriptor counts to allocated USB request capacity.
- It applies a Rack-specific playback packet-capacity adjustment for its six-output/eight-input layout.
- Further investigation found playback ring underruns and introduced a bounded 2 ms playback lead for that Rack.
- Subsequent analysis attributed some remaining underruns to delayed USB completion giveback and host scheduling/softirq behaviour.
- The documentation explicitly retains remaining failures and limits; these changes are not a blanket stability guarantee.

PR #2, “Feat/tauri editor”, merged 17 October 2026, is editor work, not a macOS audio transport change. It also has no PR comments or review submissions. No open issues were found in the checked Linux repository snapshot. Latest visible repository activity on 10 November was editor/manual work and a 0.1.2 release-candidate version bump, not a new audio-driver transport result.

**Do not transplant Eleven Rack-specific quirks** (VID/PID, endpoint numbers, channel arithmetic, feedback assumptions, packet ceilings, or the 2 ms lead) to the Mbox 2. The transferable lessons are to validate descriptor-array bounds, per-frame packet sizes, implicit/explicit feedback behaviour, queued playback headroom, completion latency and underrun recovery against the actual Mbox 2 descriptors and measurements.

## 8. Work not performed and next steps

Not performed:
- No vendor-specific or state-changing USB request.
- No SET_CONFIGURATION or SET_INTERFACE operation.
- No USB pipe submission or endpoint transfer.
- No audio streaming, firmware initialisation or LED test.
- No changes to SIP, Startup Security or device ownership.

Next:
1. Resume the Mbox 2 initialisation sequence work, including the unresolved DigiHandshake helper chain and exact startup request ordering.
2. Only after the sequence is reconciled, explain the exact first hardware request and obtain explicit user approval.
3. Once initialisation is demonstrated, implement and test the modern user-space isochronous transport against the Mbox 2's actual endpoint/alternate-setting descriptors.
4. Design the Core Audio shared transport with time/sample-position semantics where required by AudioServerPlugIn, rather than assuming a FIFO is sufficient.


## 9. Modern macOS IOUSBLib SDK compatibility check

A separate read-only inspection of the active macOS SDK header `IOKit.framework/Headers/usb/IOUSBLib.h` found that both `IOUSBInterfaceInterface192` and `IOUSBInterfaceInterface500` declare standard asynchronous isochronous read/write methods and low-latency isochronous read/write methods.

The version-500 declaration also includes `LowLatencyCreateBuffer()`, `LowLatencyDestroyBuffer()`, `GetBusMicroFrameNumber()` and `GetFrameListTime()`. The header documents preallocated buffers/frame lists and an open-interface requirement for the low-latency path. Its `updateFrequency` documentation gives a 0–8 ms range, with zero meaning update on transfer completion. These are API facts, not Mbox 2 configuration recommendations.

**Conclusion:** interface version 500 is not required solely to obtain low-latency isochronous methods; version 192 declares those methods too. Version 500 provides additional supporting buffer and timing APIs. See [Modern macOS IOUSBLib isochronous API compatibility](modern-macos-iousblib-isochronous-api-2026-11-23.md) for the full declaration-level findings and limitations.

This does not resolve the legacy submission vtable methods or identify any Mbox 2 endpoint, interface mapping, alternate setting, packet size, queue depth, feedback unit or scheduling value. No runtime USB call or hardware transfer was made.
