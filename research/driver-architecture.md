# Original driver architecture — working map

## Purpose and evidence level

This document organises the driver components identified so far on the known-working OS X Mavericks reference system. It is an initial research map, not a complete description of the driver's internal design.

The component names and version information below are directly recorded from the installed software or inspected binary. Their precise responsibilities and interactions still need to be confirmed from code, logs and runtime behaviour.

## Components identified

| Component | Recorded identifier | Current understanding |
|---|---|---|
| Mbox 2 kernel extension | `com.digidesign.mbox2.driver` | Contains Mbox 2-specific kernel-level code. The inspected binary includes USB-device, engine and user-client symbols. |
| Avid CoreAudio plug-in | `com.avid.avid.AvidCoreAudioPlugIn` | CoreAudio-facing component installed with the legacy Pro Tools software. Its exact relationship to the Mbox 2 kernel extension needs further tracing. |
| DigiDal | `com.digidesign.iokit.DigiDal` | A separate Digidesign/Avid component present in the working installation. Its exact role in Mbox 2 startup and audio operation has not yet been established. |
| macOS USB system | Apple USB driver and service layers | Provides the operating-system USB support through which the device is detected. The exact division of work between Apple's USB stack and the Mbox-specific code remains to be mapped. |

## Symbols found in the Mbox 2 kernel extension

The inspected x86_64 kernel extension contains these symbols:

- `MaudioShDrRayUsbDevice`
- `MaudioShDrRayUsbEngine`
- `RayUserClient`

These names suggest separate device, engine and user-client code areas. That interpretation is a useful guide for further inspection, but the class names alone do not prove their complete responsibilities.

The `initHardware` area also contains the string:

```
Digidesign Mbox 2 Mini11.5.0
```

This is recorded as a binary string only. It is not evidence that the original full-size Mbox 2 is internally identical to the Mbox 2 Mini.

## Initialisation and handshake code

The driver contains a routine identified as `FirmwareHandshake` at address `0x4fc6`. A separate handshake-related path includes:

| Item | Address |
|---|---:|
| `HandleDigiHandshakeProperty` | `0x9f00` |
| `DigiHandshake::Do` | `0x9f66` |
| Stage 1 helper | `0xa174` |
| Stage 4 helper | `0xa1a8` |
| Stage 2 helper | `0xa1da` |
| Stage 3 helper | `0xa1e6` |

The main routine compares its stage value with 4, consistent with stage values 0–4. The property name `LatencyProfiler` is also checked in the related code.

The addresses refer only to the inspected Mavericks x86_64 binary. The complete request sequence and the relationship between the identified routines still need to be traced.

## Provisional component picture

The following is a working investigation model, not a verified call graph:

1. macOS detects the Mbox 2 through its USB system.
2. Mbox-specific kernel code matches or opens the device and performs device initialisation.
3. The firmware handshake code participates in bringing the device into an operational state.
4. The driver exposes an audio engine or related interface to higher-level audio software.
5. The Avid CoreAudio plug-in and DigiDal participate somewhere in the wider audio-software path.

Only the USB detection and the existence of the named software components and code symbols have been established in the recorded findings. The ordering and exact responsibilities in steps 2–5 remain to be confirmed.

## Important distinctions

The investigation must keep these states separate:

- **USB detected:** macOS can enumerate the device and read its USB identity.
- **Driver attached:** the relevant Mbox-specific driver code has successfully matched and attached to the device.
- **Firmware initialised:** the required device initialisation and handshake have completed.
- **Audio engine available:** the driver exposes usable audio capabilities to macOS.
- **Clock synchronised:** the device is using the intended clock source and, for external S/PDIF, has a confirmed lock.
- **Audio streaming:** real input or output audio is passing successfully.

Evidence for one state must not be treated as proof of the later states.

## Next investigation tasks

1. Trace the Mbox 2 kernel extension's device-matching and startup entry points.
2. Follow calls between the device, engine and user-client classes.
3. Map the firmware-handshake routines to their actual USB requests and responses.
4. Identify how the kernel extension communicates with the CoreAudio plug-in and DigiDal, if at all.
5. Find the code that advertises stream formats, channel counts and sample rates.
6. Locate the code that selects internal or external clocking and reports S/PDIF lock.
7. Compare the findings with another operating-system driver only when a matching binary or reliable runtime evidence is available.

## Reference

See [Mavericks driver research](mavericks-driver.md) for the recorded reference-system versions, symbols, addresses and current unanswered questions.


## 6 November 2026 update — device class and engine creation

Further symbol and vtable inspection confirms that `RayDevice` derives from `MaudioShDrRayUsbDevice` and overrides `CreateAudioEngines()` at `0xc9ca`. The base-class implementation at `0x547a` is a stub returning `0xe00002bc`; it is not the implementation used by the concrete `RayDevice` object.

The `RayDevice` vtable symbol is at `0x272e0`, with its Itanium ABI address point at `0x272f0`. Relative virtual slot `+0xa20` resolves to `RayDevice::CreateAudioEngines()` (`0xc9ca`); slot `+0xa38` resolves to `UsbRematchInterface(unsigned char)` (`0x51b2`). The `initHardware()` calls using arguments 0 and 6 therefore request USB interface rematching, and the later `+0xa20` call creates the audio engine on the successful path.

`RayDevice::CreateAudioEngines()` allocates a `RayEngine`, initialises it using the device's stored dictionary and associated state, and registers the engine if initialisation succeeds. Exact stream formats and clocking behaviour remain to be investigated in the `RayEngine` methods.


## 7 November 2026 update — stream alternate-setting selection

Static analysis has identified `RayEngine::GetAlternateSetting()` at `0xc2d0` and the `kStreamInterface` / `kAltInfo` tables. The routine selects alternate setting 6 when AC-3 is enabled; otherwise it selects 2 when the clock-source byte is 1, or 3 for other values. The 12 alternate-setting records are 28 bytes each, with interface ID and alternate-setting number in the first two bytes. The exact record mappings and the semantic meaning of the clock-source and AC-3 inputs remain unresolved. See [Stream-interface and alternate-setting selection](stream-alternate-settings.md) for the evidence and limitations.
