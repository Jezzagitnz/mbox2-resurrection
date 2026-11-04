# Mavericks driver research

## Reference environment

The known-working reference is a 2012 Mac mini running OS X Mavericks 10.9.5, build **13F1911**. The original full-size Digidesign Mbox 2 works in this environment following installation of the relevant Pro Tools and Mbox driver software.

This system is the project's reference environment. Its known-working state should be preserved for comparison.

## Recorded software components

The following versions were identified on the reference installation:

| Component | Identifier / version |
|---|---|
| Avid CoreAudio plug-in | `com.avid.avid.AvidCoreAudioPlugIn` |
| Avid CoreAudio plug-in version | `10.3.10d613` (short version `10.3.10.613`) |
| DigiDal | `com.digidesign.iokit.DigiDal`, version `10.3.10d4` |
| Mbox 2 kernel extension | `com.digidesign.mbox2.driver`, version `10.3.9f4` |
| Mbox 2 kernel extension short version | `10.3.9.12` |
| Mbox 2 kernel extension architecture | `x86_64` only |
| Kernel extension build OS | `12F45` |
| Kernel extension SDK | `10.7` |

The exact installed files and their hashes should be recorded alongside future binary comparisons.

## Driver symbols and strings

Inspection of the Mbox 2 kernel extension identified these symbols:

- `MaudioShDrRayUsbDevice`
- `MaudioShDrRayUsbEngine`
- `RayUserClient`

The `initHardware` area contains the string:

```
Digidesign Mbox 2 Mini11.5.0
```

This string is an observation from the binary. It does not establish that the full-size Mbox 2 uses the same hardware as the Mbox 2 Mini.

## Handshake-related code

The following addresses were identified during x86_64 disassembly of the Mavericks driver:

| Item | Address |
|---|---:|
| `FirmwareHandshake` | `0x4fc6` |
| `HandleDigiHandshakeProperty` | `0x9f00` |
| `DigiHandshake::Do` | `0x9f66` |
| Stage 1 helper | `0xa174` |
| Stage 4 helper | `0xa1a8` |
| Stage 2 helper | `0xa1da` |
| Stage 3 helper | `0xa1e6` |

The `DigiHandshake::Do` routine compares the stage value against 4, consistent with stage values 0 through 4. The property name `LatencyProfiler` is also checked in the handshake-related code.

The relocation table was reported to contain 5,969 external relocation entries.

These addresses are specific to the inspected binary build and architecture. They must not be treated as stable addresses across other driver versions.

## What this establishes

The original driver contains identifiable USB-device, engine and user-client classes, plus a multi-stage handshake path. This gives the investigation concrete code locations to examine further.

## What remains unknown

- The complete USB request sequence for each handshake stage.
- The exact request types, values, indices, payloads and expected responses.
- Whether all five stage values are used on every hardware or firmware revision.
- The exact point at which the device becomes ready for audio streaming.
- The complete audio transport and clock-control implementation.
- Whether the same behaviour is present in other operating-system driver versions.

## Next evidence to collect

For each relevant routine, preserve the disassembly with surrounding control flow, referenced constants, called functions and relocation information. Link observations to the exact driver binary and its hash so that later comparisons remain meaningful.
