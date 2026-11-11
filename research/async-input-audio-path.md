# Mbox 2 asynchronous input transport and sample-buffer path

**Research date:** 11 November 2026  
**Reference environment:** OS X Mavericks 10.9.5, build 13F1911 (previously recorded reference system)  
**Binary:** `/System/Library/Extensions/DigidesignMbox2.kext/Contents/MacOS/DigidesignMbox2`  
**Driver version:** 10.3.9f4 (short version 10.3.9.12), as recorded in [Mavericks driver research](mavericks-driver.md)  
**Architecture inspected:** x86_64  
**Evidence type:** `nm` symbol output and `otool -arch x86_64 -tvV` disassembly. Static analysis only; no runtime stream trace or audio capture was performed.

## Scope

This note records the first detailed map of the legacy driver's `MaudioShDrRayUsbInterfaceAsyncRead` path: low-latency isochronous frame submission, completion handling, input-frame copying, sample-buffer wrap handling, and the associated sample-rate tracking code.

The 11 November terminal captures identify the standard Mavericks kext path and x86_64 disassembly. The OS build and driver version above are carried forward from the previously recorded reference-system inventory; the captures themselves do not include a fresh `sw_vers` or binary-hash result.

## Relevant symbols

| Method | Address |
|---|---:|
| `MaudioShDrRayUsbInterfaceAsyncRead::init` | `0x2e12` |
| `MaudioShDrRayUsbInterfaceAsyncRead::Start` | `0x2f42` |
| `MaudioShDrRayUsbInterfaceAsyncRead::UsbFrameListSubmit` | `0x3036` |
| `MaudioShDrRayUsbInterfaceAsyncRead::SetAlternateSetting` | `0x3260` |
| `MaudioShDrRayUsbInterfaceAsyncRead::UsbFrameListInit` | `0x3396` |
| `MaudioShDrRayUsbInterfaceAsyncRead::UsbFrameListHandler` | `0x33c4` |
| `MaudioShDrRayUsbInterfaceAsyncRead::CopyInputFrames` | `0x344a` |
| `MaudioShDrRayUsbInterfaceAsyncRead::FinalizeBuffers` | `0x3692` |
| `MaudioShDrRayUsbInterfaceAsyncRead::CopyBufferFrameToSample` | `0x37c8` |
| `MaudioShDrRayUsbInterfaceAsyncRead::TrackSampleRate` | `0x38d4` |
| `MaudioShDrRayUsbInterfaceAsyncRead::CheckForSampleRateChange` | `0x39ac` |
| `MaudioShDrRayUsbInterfaceAsyncRead::FixBytesToCopy` | `0x3ad8` |
| `MaudioShDrRayUsbInterfaceAsyncRead::SetExternalSampleRate` | `0x3afc` |
| `MaudioShDrRayUsbInterface::IncrementSampleFrameCountUsingBytes` | `0x237c` |
| `MaudioShDrRayUsbInterface::BufferWrapped` | `0x23b0` |
| `MaudioShDrRayUsbInterface::TakeFirstTimeStamp` | `0x2556` |

These addresses are specific to the inspected binary and must not be reused as offsets for another driver build.

## Confirmed observations

### Buffer and frame-list allocation

`FinalizeBuffers()` at `0x3692` prepares the asynchronous read buffers:

- It obtains a 16-bit value through the USB-interface object at `+0xc0`, via an unresolved vtable slot at byte offset `0x1a0`.
- It divides that value by the per-sample-frame byte count at object offset `+0x124`, then stores an aligned value at `+0x12c`. This aligned value is used as the requested byte count for each isochronous frame.
- It sets the frame-list count at `+0x198` to `0xc8` (200).
- It allocates `0x190` (400) isochronous frame descriptors.
- It allocates `0xc8` (200) completion records.
- It passes the 200-entry frame-list description and the two-frame byte-buffer size to the USB-buffer allocator, then allocates the audio sample buffer.

The `+0x124` value is used as bytes per audio sample frame. The `SetFormat()` path at `0x184c` derives it from the channel count and the bit-depth-in-bytes calculation. The exact names of all intermediate object fields have not been recovered from type information.

The counts are consistent with a ring of 200 frame-list submissions, each containing two 16-byte `IOUSBLowLatencyIsocFrame` descriptors: 400 descriptors in total.

### Descriptor layout and submission

`UsbFrameListInit()` at `0x3396` advances through descriptors in 16-byte steps and writes:

| Descriptor offset | Value written |
|---|---|
| `+0x00` | `0x6c6c6974` (the little-endian bytes spell `till`; used as a marker) |
| `+0x04` | Requested frame byte count from object offset `+0x12c` |
| `+0x06` | Zero, ready to be replaced by the completed byte count |

The consumer later reads the 16-bit field at descriptor offset `+0x06` as the number of bytes received and reads the 64-bit timestamp at `+0x08`. This matches the expected field positions in the low-latency isochronous frame structure.

`UsbFrameListSubmit()` at `0x3036`:

1. Reads the current USB frame number.
2. Selects a pair of descriptors from the 400-entry descriptor ring.
3. Initializes two descriptors, each 16 bytes long.
4. Calls an interface-object vtable slot at byte offset `0x1f8`, passing a frame count of `2` and the frame-list/completion data.
5. On a successful submission, increments the outstanding-completion counter at `+0x1f4`, advances the scheduled USB frame number by two, and advances the 200-entry frame-list index with wraparound.

The exact name and full signature of the virtual submission method at `+0x1f8` have not yet been resolved. The surrounding types and callback identify this as the low-latency isochronous frame-list path, but the vtable slot should remain unnamed until its relocation is mapped.

### Start-up queue and completion callback

`Start()` at `0x2f42` resets the frame indices, counters and sample-buffer offset, records the initial USB frame number, and calls `InitSampleFrameCount()`. It then calls `UsbFrameListSubmit()` 50 times before setting the interface state to numeric value `2` and setting the start flag at `+0x134`.

Because each submission contains two isochronous frame descriptors, the initial loop requests 50 two-frame submissions (100 frame descriptors). This is the code's initial queueing behaviour; it is not proof that all submissions complete successfully on hardware.

The completion callback `UsbFrameListHandler()` at `0x33c4`:

- Atomically decrements the outstanding-completion counter at `+0x1f4`.
- Checks the running/stopping flags.
- When the engine pointer at `+0xa0` is present and the path is running, calls `CopyInputFrames(0)`.
- If the pending-resubmission count at `+0x2ac` is positive, submits more frame lists and decrements that count.
- Uses the base callback vtable slot at `+0x28` on exit.

This establishes a completion-driven consume-and-resubmit loop in the static code.

### Input-frame consumption

`CopyInputFrames()` at `0x344a` takes an I/O lock at `+0x290`, then processes entries from the descriptor ring:

- The descriptor array is referenced through `+0x208`.
- The current descriptor index is stored at `+0x238`; the index advances through a 400-entry ring using a 16-byte stride.
- The completed byte count is read from descriptor offset `+0x06`.
- The descriptor timestamp is read from offset `+0x08`.
- The per-frame payload pointer is calculated from the payload-buffer base at `+0x1a8` plus the descriptor index multiplied by the per-frame allocation size at `+0x12c`.

When the object field at `+0x10c` equals `2`, the routine calls `TrackSampleRate(actualByteCount)` and `CheckForSampleRateChange()`. The meaning of this mode value is not yet established.

For a nonzero completed byte count and no pending fallback condition, the routine calls `CopyBufferFrameToSample(payload, actualByteCount, timestamp)`. It then advances the descriptor index and continues accounting for the bytes copied.

A zero completed byte count takes a separate recovery path. The code sets a flag at `+0x280`, calculates a fallback byte count as `+0x124 * +0xfc`, copies from an alternate buffer pointer at `+0x1d8`, and reports error value `0xe00002e7` through `RayEngine::ReportHardwareError()`. The meanings of `+0xfc`, `+0x1d8`, the flag, and the error value are not yet resolved.

### Copying into the audio sample ring

`CopyBufferFrameToSample()` at `0x37c8` validates the source pointer and byte count, then copies the payload into a circular sample buffer:

| Object offset | Use observed in this method |
|---|---|
| `+0x218` | Sample-buffer base pointer |
| `+0x220` | Sample-buffer capacity |
| `+0x228` | Current write offset |

The method uses `memcpy`. If the write crosses the end of the sample ring, it copies the data in two pieces and calls `BufferWrapped(timestamp, bytesAfterWrap, totalByteCount)`. It then updates the write offset modulo the sample-buffer capacity.

This method performs byte copying and ring-buffer management; it contains no explicit endian swap, bit-depth conversion or PCM sample decoding. That is a statement about this method only. Other paths or earlier/later stages may perform format-specific work.

`BufferWrapped()` at `0x23b0` increments a wrap counter at `+0x194`. When nonzero byte counts are supplied, it derives a nanosecond adjustment from the byte-count ratio, converts that interval to absolute time, adjusts the supplied timestamp, and calls `RayEngine::TakeTimeStamp()`. The call also supplies a boolean derived from object state at `+0x108`.

`TakeFirstTimeStamp()` at `0x2556` subtracts an interval converted from 1,000,000 nanoseconds (1 ms) from the first timestamp before forwarding it to `RayEngine::TakeTimeStamp()`. The exact timing rationale has not yet been established.

### Sample-rate tracking path

`TrackSampleRate()` at `0x38d4` is called with the completed USB-frame byte count in the mode-`2` path:

1. It divides the completed byte count by the per-sample-frame byte count at `+0x124`.
2. It multiplies the resulting whole-sample count by 1,000 to form a rate estimate.
3. It passes that estimate to `GetClosestValidSampleRate()` on the interface service.
4. It maintains candidate/current rate fields and uses a 16-count field when the candidate differs.

The factor of 1,000 is consistent with deriving a rate from a per-millisecond USB frame, but the timing assumption has not yet been independently confirmed from the complete transfer setup.

`CheckForSampleRateChange()` at `0x39ac` compares the tracked and pending rate state. Under its state/counter conditions it calls `SetExternalSampleRate()` at `0x3afc`. This is evidence of a rate-detection/update path; it does **not** establish that mode value `2` is S/PDIF, that an external clock is locked, or that the device is receiving a valid external clock.

The asynchronous-read `init()` routine at `0x2e12` also initializes an internal rate field at `+0x264` to `0xbb80` (48,000) and clears a related field at `+0x268`. This is an object-initialization value, not proof of the active hardware rate or the complete set of supported rates.

## Interpretation — provisional

- The symbols and call sequence describe an asynchronous USB input path that consumes completed low-latency isochronous frames and moves their payload bytes into an audio sample ring.
- The 200 frame-list entries, two descriptors per submission, 400-descriptor ring and 50 initial submissions form a bounded, completion-driven queue.
- The `CopyBufferFrameToSample()` implementation appears to preserve the incoming sample-byte representation while handling circular-buffer placement and timestamps. It does not show format conversion itself.
- The mode-`2` branch appears to estimate sample rate from the actual bytes received per USB frame and pass a stable change to an external-rate update routine. Its relation to any particular physical clock input remains unknown.

These interpretations are based on static control flow. They do not prove successful USB transfers, valid sample data, CoreAudio delivery, or clock synchronisation.

## Unresolved questions

1. What exact IOUSBInterface method and signature correspond to vtable slot `+0x1f8`?
2. What is the complete type/layout of the frame-list, completion and payload-buffer structures?
3. What do object fields `+0xfc`, `+0x10c`, `+0x12c`, `+0x1d8`, and `+0x280` represent by name?
4. What condition selects mode value `2`, and is it associated with an external clock, a particular stream type, or another controller state?
5. What exact sample-rate stability/confirmation logic is implemented by the 16-count field and the state machine in `CheckForSampleRateChange()`?
6. How does `SetExternalSampleRate()` propagate the detected rate to the engine and USB device?
7. Where, if anywhere, are endian, bit-depth or sample-format conversions performed for the input and output paths?
8. What is the exact timing interpretation of the USB-frame timestamps and the 1 ms first-timestamp adjustment?
9. Does the asynchronous output path use the same buffer, timestamp and sample-rate rules?
10. Does the code behave identically across all Mbox 2 hardware/firmware revisions?

## Next evidence to collect

- Resolve the IOUSBInterface vtable relocation for slot `+0x1f8` and record the target method/signature.
- Correlate the frame-list and completion structures with the matching Mavericks IOKit headers.
- Trace the setters/getters for object field `+0x10c`, the external sample-rate controller enum, and `SetExternalSampleRate()`; keep the mode value opaque until that trace is complete.
- Trace the asynchronous output and adaptive read/write implementations to determine whether format conversion occurs elsewhere.
- Preserve the inspected binary's SHA-256 alongside future disassembly captures before comparing another driver build.

## Reproduction commands

The symbol and disassembly commands used for this pass were run against the Mavericks kext binary:

```sh
MAINBIN="/System/Library/Extensions/DigidesignMbox2.kext/Contents/MacOS/DigidesignMbox2"

nm -n "$MAINBIN" | c++filt | grep 'MaudioShDrRayUsbInterfaceAsyncRead'
otool -arch x86_64 -tvV "$MAINBIN" | grep -A120 '0000000000003036'
otool -arch x86_64 -tvV "$MAINBIN" | grep -A120 '000000000000344a'
otool -arch x86_64 -tvV "$MAINBIN" | grep -A120 '00000000000037c8'
otool -arch x86_64 -tvV "$MAINBIN" | grep -A100 '00000000000038d4'
```

The command output should be retained with the exact binary hash and OS build when these findings are revisited.
