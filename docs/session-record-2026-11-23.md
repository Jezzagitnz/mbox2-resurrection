# Session record — 23 November 2026

## Summary

This session used the Mavericks Mac mini for targeted static analysis of the original DigidesignMbox2.kext, concentrating on audio transport after the previous startup and USB-interface research. It also rechecked the two Eleven Rack reference repositories, their current discussions and the relevant merged Linux driver work.

The session produced a detailed transport note: [Legacy Mbox 2 audio transport — static analysis](../research/legacy-audio-transport-2026-11-23.md).

## Mbox 2 legacy-driver findings

### Audio interface selection

- kStreamInterfaceE at 0x1dab0 contains four 12-byte records; kStreamInterfaceCount is four.
- CreateAudioInterfaceServices() enumerates USB interfaces and matches their interface number against the first byte of each record.
- The four audio interface numbers are 2, 3, 4 and 5, matching the four AudioStreaming interfaces in the already-parsed Mbox 2 configuration descriptor.
- The remaining bytes in those records are not yet interpreted.
- GetAlternateSettingInfo() scans 12 entries in kAltInfoE at 0x1db30, using a 28-byte stride. Entries are keyed by interface number and alternate-setting number and copy 28 bytes to the caller. Remaining field meanings are open.

### Transfer implementation factory

CreateAudioInterface() at 0x45b2 maps selector values to concrete classes:

| Selector | Class |
|---:|---|
| 3 | AdaptiveRead |
| 4 | AdaptiveWrite |
| 5 | AsyncRead |
| 6 | AsyncWrite |

The class-selection mapping is direct from the jump table. The complete call-site chain supplying the selector has not been traced, so the mapping is not yet assigned to particular interfaces or endpoints.

### Frame-clock scheduling

- Interface-level GetUsbFrameNumber() reaches the USB controller's frame-number method through the interface/device/bus relationship. Apple's IOUSBInterfaceUserClient source corroborates this object chain.
- RayEngine::GetUsbFrameNumberStart() chooses current USB frame +2; when its alignment flag is true, it rounds up to a four-frame boundary.
- performAudioEngineStart() uses the asynchronous property to select the aligned target.
- MaudioShDrRayUsbStream::Start() starts active interface services and launches WaitForStreamingStartThread(), which waits against the USB controller's frame counter.
- The worker's observed accepted target-distance window is 1–999 frames; a missed or out-of-range target transitions the stream to failure.
- StartStreams() coordinates ready streams against the same target.

### Isochronous transfer queues

- The driver uses IOUSBLowLatencyIsocFrame structures and separate read/write submission and completion handlers.
- AsyncRead::UsbFrameListSubmit() reads the controller frame number, constructs two frame records, submits via an unresolved USB-interface virtual method, then advances its schedule by two frames.
- AsyncWrite::UsbFrameListSubmit() initialises four frame records with FeedbackData, submits through a separate unresolved virtual method, then advances by four frames.
- AsyncWrite::TransferAudio() invokes TransferAudioPerform() and checks completed frames based on current USB frame position.
- The engine's output and input transfer loops iterate active/streaming interface services and route audio buffers through TransferAudio(). The service method checks active state and dispatches to the concrete interface class; it is not itself the USB submission.
- The symbol UsbPipeRetain(IOUSBPipe*) exists on AsyncFeedback, but the exact USB submission virtual methods remain unresolved. The read/write call sites use interface-object vtable offsets +0x1f8 and +0x200 respectively; do not assign API names without further ABI evidence.

## Interpretation for our implementation

The original Mbox 2 driver uses scheduled low-latency isochronous frame lists, asynchronous completion handling, distinct input/output paths and USB-controller-frame timing. The write path explicitly receives FeedbackData. These are key design requirements to investigate in the modern user-space implementation.

The old kernel API is not automatically portable to our modern user-space process. The exact USB submission calls, packet layouts, feedback semantics, and interface/alternate-setting mapping still require verification. The modern implementation must retain ordinary non-forcing USB access and must not seize the device.

## Eleven Rack repository checks

### Apple Silicon macOS reference

Repository: https://github.com/Matt-Housley/eleven-rack-driver

- README documents release 1.1.0 and a user-space engine, Core Audio AudioServerPlugIn, shared-memory ring and menu-bar supervisor.
- The inspected source uses IOUSBDeviceInterface500 / IOUSBInterfaceInterface500 and ReadIsochPipeAsync()/WriteIsochPipeAsync().
- The engine calls USBDeviceOpen(), then falls back to USBDeviceOpenSeize() on kIOReturnExclusiveAccess. This fallback conflicts with our explicit no-seize/no-forced-takeover rule and must not be copied.
- The current source's shared ring is version 7. Capture is an SPSC FIFO; playback is a time-addressed ring using Core Audio output sample time, with the engine play head trailing the furthest written sample time. This is an important warning against using an append-only playback FIFO in our AudioServerPlugIn implementation.
- The playback-dropout analysis document's status line says the time-addressed fix is not implemented, while current source includes time-addressed playback-ring code. This is a documentation inconsistency; current validation/release status should not be inferred from that stale status line.
- Issues #1 (endpoint 0x83 transaction-error recovery) and #2 (our USBDeviceOpenSeize/SIP/signing question) have no comments or maintainer replies. No public PR was found in the checked repository.

### Linux Eleven Rack reference

Repository: https://github.com/kdbo/Elevenrack-driver-linux

- It is a Linux snd-usb-audio/ALSA kernel-driver patch for Eleven Rack USB ID 0dba:b011, not a macOS implementation.
- PR #1, “Fix/implicit feedback packet capacity”, is merged (16 October 2026); no PR discussion comments or review submissions were found. Its current documentation records later work through 20 October: descriptor-count bounds, Rack-specific playback packet-size normalization, a 2 ms playback lead to prevent playback-ring underruns, and further delayed-completion/giveback analysis.
- PR #2, “Feat/tauri editor”, is merged (17 October 2026), is editor work rather than audio-driver transport work, and has no comments or review submissions.
- No open issues were found in the checked repository snapshot. Latest visible repository activity (10 November) concerns editor/manual changes and a 0.1.2 release candidate, not new audio transport work.
- Rack-specific endpoint, packet-size, channel-count, feedback and playback-lead quirks must not be copied to Mbox 2. Only the general engineering lessons about bounded frame descriptors, feedback, queue depth, completion latency and underrun handling transfer.

## GitHub project checks

- Mbox 2 Resurrection PR #25 remains open and mergeable. It had no comments, submitted reviews or inline review threads at the time of this check. Its current head commit reported no status checks.
- This session's documentation will be added to the existing PR #25 branch; the PR will remain open and will not be merged by this update.

## Work not performed

No vendor-specific or state-changing USB request was sent. No SET_CONFIGURATION, SET_INTERFACE, USB pipe submission, endpoint transfer, audio streaming, firmware initialisation or LED test was performed. No SIP or Startup Security setting was changed, and no device seize/capture was attempted.

## Next steps

1. Continue the narrowly scoped startup analysis, especially the unresolved five-stage DigiHandshake::Do helper chain and request ordering.
2. Reconcile the Mavericks and Linux startup exchanges before proposing any hardware request.
3. Explain the exact request, expected response, retry/timeout behaviour and safe stopping conditions; obtain explicit user approval before any vendor-specific or state-changing USB request.
4. After the LED/initialisation milestone, implement the user-space isochronous transport using the actual Mbox 2 descriptors and verified modern USB APIs.
5. Design and test the Core Audio shared transport with correct IO-cycle sample-time semantics and multi-client playback behaviour.
