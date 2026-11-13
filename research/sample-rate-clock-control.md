# Sample-rate, clock and USB stream control

**Research update: 13 November 2026**

## Scope and evidence

This note records static analysis of the original Digidesign Mbox 2 Mavericks kernel extension:

`/System/Library/Extensions/DigidesignMbox2.kext/Contents/MacOS/DigidesignMbox2`

The inspected binary is the x86_64 Mbox 2 driver version 10.3.9f4 (short version 10.3.9.12) from the known-working OS X Mavericks 10.9.5 reference installation.

The findings below are based on symbol inspection, disassembly and examination of the relevant Apple USB headers. They describe code paths and constructed requests; they do not establish successful audio operation on modern macOS. Addresses are specific to this binary and must not be assumed stable across driver builds.

Evidence labels:
- **Confirmed in disassembly** — directly visible in the inspected machine code or data.
- **Strong indication** — the code strongly supports the interpretation, but a relevant API mapping or runtime result is not yet confirmed.
- **Open** — further disassembly, descriptor capture or hardware testing is required.

## 1. Supported sample-rate selection

**Confirmed in disassembly**

- The driver's `kValidSampleRate` table contains two entries: **44,100 Hz** and **48,000 Hz**.
- The table count is 2.
- `GetMinSampleRateFromPrefSettings` at `0xc1aa` returns 8,000 Hz.
- `GetMaxSampleRateFromPrefSettings` at `0xc190` returns 48,000 Hz.
- The 8,000–48,000 Hz values are preference/configuration bounds, not a list of rates the hardware supports.
- `GetClosestValidSampleRate` at `0x6a14` searches the valid-rate table for the closest supported value, then checks that result against the current configuration's permitted range.

The current static evidence therefore identifies 44.1 and 48 kHz as the driver's explicit valid sample rates. It does not yet establish every supported combination of sample rate, bit depth, clock source and stream mode.

## 2. Engine-level sample-rate reconfiguration

**Confirmed in disassembly**

Relevant routines include:

| Routine | Address | Observed role |
|---|---:|---|
| `RayEngine::SetSampleRate` | `0xc038` | Coordinates engine and active-stream changes |
| `CalculateBufferSizeInSampleFrames` | `0x75fa` | Calculates buffer sizing from rate information and another parameter |
| `setSampleRate` | `0x6b60` | Validates/reconciles a requested rate and updates engine state |
| `CommonConfigureSteps` | `0x6d28` | Runs engine and stream configuration calls |
| `SetConfiguration` | `0x7028` | Coordinates configuration changes |
| `DoSetConfiguration` | `0x708a` | Applies configuration to the two stream directions |
| `FixConfigurationSampleRate` | `0x6f98` | Constrains a rate to the current configuration range |

The `RayEngine::SetSampleRate` path recalculates buffer sizing, updates engine state and walks active stream objects. It sets external-rate mode on active streams and calls stream virtual methods at offsets `+0xb70` and `+0xb58`; on success it calls an engine virtual method at `+0xb68`.

The identities of those three virtual methods have not yet been resolved. The exact meaning of the extra parameter used in buffer-size calculation also remains open.

The configuration path handles two stream directions and can invoke firmware-handshake logic while changing configuration. It also contains a special controller-mode branch that changes device/interface state. The full semantics of that branch are not yet established.

## 3. USB endpoint sampling-frequency requests

**Confirmed in disassembly**

Two methods in `MaudioShDrRayUsbInterface` construct USB control requests:

| Method | Address | Request fields |
|---|---:|---|
| `SetSampleRate` | `0x1982` | `bmRequestType=0x22`, `bRequest=0x01`, `wValue=0x0100`, `wIndex=endpoint address`, `wLength=3` |
| `GetSampleRateFromInterface` | `0x1b14` | `bmRequestType=0xA2`, `bRequest=0x81`, `wValue=0x0100`, `wIndex=endpoint address`, `wLength=3` |

The endpoint address is obtained from the endpoint descriptor. The set path sends a three-byte sample-frequency value; the get path requests three bytes and copies the returned value into its output structure.

The set routine also checks the interface's streaming state. If the state equals 2, it refuses the change, logs that the sample rate cannot be changed while streaming, waits, and returns an error. After a successful request it caches rate and timing-related state and performs further interface reconfiguration.

**Strong indication:** the request types and request codes match USB Audio Class endpoint sampling-frequency controls:
- `0x22 / 0x01` is class-specific endpoint `SET_CUR`.
- `0xA2 / 0x81` is class-specific endpoint `GET_CUR`.

This demonstrates use of the USB Audio Class-style sampling-frequency control convention. It does **not** establish that the entire Mbox 2 is a standard USB Audio Class device; the driver also contains Digidesign-specific initialisation and vendor requests.

### Apple USB API mapping remains open

The Apple Mavericks headers show:
- `IOUSBInterface::DeviceRequest(IOUSBDevRequest *)`, for a control request on the device's default control pipe (endpoint zero).
- `IOUSBPipe::ControlRequest(IOUSBDevRequest *)`, for a control request through a pipe.

The disassembled request fields are consistent with an `IOUSBDevRequest` structure. However, inspecting the header declarations alone does not identify the exact virtual method called by the driver's indirect call at vtable offset `+0x8e8`. The object/register used at that call and the relevant vtable layout still need to be resolved. Do not document `+0x8e8` as either named API until that mapping is proven.

## 4. External sample-rate detection and clock tracking

**Confirmed in disassembly**

The external-rate path spans the engine, active streams, stream services and USB-interface objects:

- `SetSampleRateFromUsbFrameListHandler` in the engine is at `0x7546`.
- `SetSampleRateFromUsbFrameListHandlerAction` is at `0x6ce4`.
- The service-side frame-list handler stores incoming rate information and dispatches work to the engine.
- `AsyncRead::SetExternalSampleRate` at `0x3afc` forwards rate information only under particular controller and enable-state conditions.
- `AsyncFeedback::SetExternalSampleRate` at `0xd14c` copies rate information into feedback state.
- `ProcessFeedbackData` at `0xd1ae` performs fixed-point calculations.
- `CheckForSampleRateChange` at `0xd206` compares feedback values and applies a stability/debounce check before accepting a change.
- `RayEngine::SetPrimaryInterfaceForExternalSampleRateChanges` at `0xbf54` selects the relevant stream service path.
- `RayEngine::ActivateExternalSampleRateController` at `0xbbd0` and the stream/service methods forward controller state to active interfaces.

The underlying USB-interface method stores the controller enum at object offset `+0x10c`; the external sample-rate mode is stored at `+0x110`. These methods store control state and do not themselves issue a USB request.

The service classification code identifies asynchronous, asynchronous-write, adaptive-read and virtual service categories. Type 6 is explicitly asynchronous-write; type 3 is explicitly adaptive-read. Type 5 falls within the asynchronous range, but its more specific identity should remain provisional until the relevant service class is fully mapped.

**Open:** the numeric meaning of the controller enum, the units/scaling of the feedback calculations, the exact stability threshold, and the mapping of these paths to the physical S/PDIF input/output are not yet established. Do not equate the legacy utility's “locked” indicator with confirmed S/PDIF clock lock.

## 5. Stream interfaces, alternate settings and AC-3 preference

The driver has a four-entry stream-interface table containing interface numbers **2, 3, 4 and 5**. Its alternate-setting lookup table contains 12 records, each 28 bytes long. The records cover alternate settings 0, 2 and 3 for those interfaces; alternate setting 1 does not appear in this driver's lookup table. That does not prove it is absent from the device's raw USB descriptors.

`RayEngine::GetAlternateSetting` at `0xc2d0` selects:
- alternate setting 6 when the AC-3 preference is enabled;
- otherwise alternate setting 2 when the clock-source preference byte equals 1;
- otherwise alternate setting 3.

The preference data is a two-byte structure stored at device offset `+0x158`:
- byte 0 is read as the clock-source preference;
- byte 1 is read as the AC-3 preference.

The preference-data handler requires exactly two bytes and calls back into the engine to reconfigure.

The AC-3 preference changes more than a simple PCM bit-depth setting:
- `IsInterfaceEnabled` enables only interface 3 when AC-3 is selected; otherwise its bitmask enables interfaces 2, 4 and 5.
- `IsEnabledForInput` returns false when AC-3 is selected.
- `IsEnabledForOutput` returns true.
- `IsBitDepth16` follows the AC-3 preference; `IsBitDepth24` is its inverse.
- The initial-format routine changes format depth and channel-count calculations according to the enabled interfaces and direction.

The live Mavericks interface state observed during earlier inspection had interfaces 2, 4 and 5 at alternate setting 3, while interface 3 was idle at alternate setting 0. This is consistent with the non-AC-3 path described by the static code. The AC-3 alternate-setting-6 path has not yet been validated against a complete live descriptor capture or a hardware test.

The exact interpretation of the clock-source enum values remains unresolved. In particular, do not label value 1 as a specific physical clock source until confirmed.

## 6. Relationship to device initialisation

The separate `FirmwareHandshake` routine at `0x4fc6` sends a vendor-specific control request:

| Field | Value |
|---|---:|
| `bmRequestType` | `0xC0` |
| `bRequest` | `0x85` |
| `wValue` | Boolean argument + 1 |
| `wIndex` | `0x0001` |
| `wLength` | 1 |

It polls a one-byte response, retrying when the response equals 1. This is distinct from the three-byte endpoint sampling-frequency requests described above. The common presence of USB control transfers does not make these protocols interchangeable.

## 7. Current conclusions

The original driver is not simply advertising a fixed audio format. It has a layered configuration mechanism:

1. It chooses a supported sample rate from an explicit 44.1/48 kHz table.
2. It reconciles that rate with the current configuration's permitted range.
3. It coordinates buffer and stream reconfiguration in the audio engine.
4. It uses USB endpoint sampling-frequency control requests to set and read back a rate.
5. It has separate feedback and frame-list paths for detecting and tracking an external rate.
6. It selects stream-interface alternate settings according to clock and AC-3 preferences.

This is a substantial improvement in our understanding of the original driver. It is still static reverse-engineering evidence, not a working modern driver or proof of successful input/output audio.

## 8. Next investigation steps

1. Resolve the object and vtable behind the indirect call at `+0x8e8`; identify the exact Apple USB request method.
2. Map the engine virtual calls at `+0xb40`, `+0xb68`, `+0xb70`, `+0xb58`, `+0xc30`, `+0xcc0` and the relevant configuration slots.
3. Capture complete raw USB descriptors for interfaces 2–5, including endpoint addresses, directions, transfer types, packet sizes and alternate-setting-specific details.
4. Decode the three-byte sample-rate representation and feedback fixed-point units.
5. Determine the meanings of the clock-source and external-controller enum values.
6. Correlate static findings with observable behaviour on the working Mavericks system, including actual internal/external clock changes and audio streaming.
7. Only then translate the confirmed behaviour into the modern macOS driver and control-utility design.
