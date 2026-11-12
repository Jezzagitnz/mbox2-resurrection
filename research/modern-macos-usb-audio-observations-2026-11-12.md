# Modern macOS Mbox 2 USB and Core Audio observations

**Observation date:** 12 November 2026  
**Test environment:** Work Mac running a current macOS release (Tahoe); exact Mac model and OS build were not recorded in this session  
**Device:** Original full-size Digidesign Mbox 2  
**Evidence type:** Read-only IORegistry, System Information, Audio MIDI Setup, System Settings and Unified Log inspection

## Summary

The Mbox 2 enumerates successfully on the tested modern Mac and appears in the system's audio-device inventory. However, macOS does not expose usable input/output channels or audio formats, and the device does not appear as a selectable input or output in System Settings > Sound.

This reproduces the previously observed modern-Mac behaviour. It narrows the failure to a stage after basic USB enumeration, but does not identify the exact cause. In particular, the available evidence does not prove whether the legacy firmware handshake failed, whether the generic Apple USB audio driver rejected a stream configuration, or whether another device-initialisation step is missing.

## USB device identity and configuration

The IORegistry reported an active `IOUSBHostDevice` for `Mbox 2@20300000` with these properties:

| Property | Observed value |
|---|---:|
| Manufacturer | Digidesign |
| Product | Mbox 2 |
| Vendor ID | `0x0dba` (3514) |
| Product ID | `0x3000` (12288) |
| Device revision (`bcdDevice`) | `312` / `0x0138` |
| USB version (`bcdUSB`) | `256` / `0x0100` |
| USB speed | `1` (reported as Full Speed, 12 Mb/s) |
| Active configuration | `1` |
| Maximum power allocation | 500 mA |
| Device state | Registered, matched and active |

This confirms USB enumeration and selection of configuration 1. It does not prove that the Mbox-specific initialisation sequence completed or that audio endpoints are operating.

## Instantiated USB interface objects

A read-only query of current `IOUSBHostInterface` objects returned the following interface layout:

| Interface | Class | Subclass | Alternate setting | Endpoints reported | Additional observation |
|---:|---:|---:|---:|---:|---|
| 0 | `0xfe` (254) | `0x01` | 0 | 0 | Vendor-specific interface |
| 1 | `0x01` | `0x01` | 0 | 0 | Audio Control; a `usbaudiod` client was attached |
| 2 | `0x01` | `0x02` | 0 | 0 | Audio Streaming; `AppleUSBAudioStreamPropertiesReady = Yes`; `usbaudiod` client attached |
| 3 | `0x01` | `0x02` | 0 | 0 | Audio Streaming; `AppleUSBAudioStreamPropertiesReady = Yes`; `usbaudiod` client attached |
| 4 | `0x01` | `0x02` | 0 | 0 | Audio Streaming; `AppleUSBAudioStreamPropertiesReady = Yes`; `usbaudiod` client attached |
| 5 | `0x01` | `0x02` | 0 | 0 | Audio Streaming; `AppleUSBAudioStreamPropertiesReady = Yes`; `usbaudiod` client attached |
| 6 | `0xff` (255) | `0x00` | 0 | 3 | Vendor-specific interface |

**Important limitation:** this is a listing of instantiated interface objects and their current alternate settings, not a complete raw configuration-descriptor dump. The fact that only alternate setting 0 appeared in this query does not prove that the device descriptor contains no other alternate settings. Likewise, the zero endpoint counts shown for the current Audio Streaming interface objects do not establish that the underlying configuration has no streaming endpoints at other alternate settings.

A separate query for `IOUSBHostPipe` objects did not return matching pipe objects. This is an observation about that registry query, not proof that no endpoint pipes can be created.

## Core Audio and user-visible behaviour

The following behaviour was observed with the Mbox 2 connected:

- Audio MIDI Setup lists **Mbox 2**, but reports **“no valid formats available.”**
- System Settings > Sound does not offer Mbox 2 as an input or output device.
- `system_profiler SPAudioDataType -detailLevel full` reports the Mbox 2 manufacturer as Digidesign, transport as USB, and a current sample-rate value of 48,000 Hz.
- That System Profiler entry does not report input or output channel counts for the Mbox 2.
- A search for an `AppleUSBAudioEngine` IORegistry object matching Mbox 2 or Digidesign returned no result in the queried registry view.
- The physical USB indicator on the Mbox 2 was observed to be off during this test.

The reported 48 kHz value must not be treated as proof of a valid 48 kHz stream. In the absence of published channels and formats, it may be only a device-level or default rate property.

## Unified Log observation

A 15-minute Unified Log query filtered to process `usbaudiod` and terms related to the Mbox, USB, streams, formats, interfaces, endpoints and errors returned only one matching entry: a routine CoreAnalytics configuration update from `usbaudiod`.

No Mbox-specific error or stream-configuration message appeared in that filtered output. This is not proof that no error occurred: relevant messages may be emitted by another process, omitted at the selected log level, redacted, or outside the time window.

## What this establishes — and what it does not

**Established:**

- The modern USB host detects the expected Digidesign VID/PID.
- The device has configuration 1 active and appears as an audio device in system inventory.
- Apple’s `usbaudiod` service has client objects attached to the Audio Control and Audio Streaming interface objects.
- The user-facing audio stack does not expose usable formats or input/output channels in this test.

**Not established:**

- Whether the Mavericks firmware handshake succeeds or fails on modern macOS.
- Whether the full alternate-setting and endpoint descriptors are parsed correctly by the generic Apple driver.
- Whether the Apple audio service successfully claims and configures the required streaming alternate settings.
- Whether the device is in its normal audio-operating state.
- Whether S/PDIF clock detection, sample-rate changes, or actual audio transfers work.
- Whether the USB indicator being off is a reliable diagnostic of any one initialisation stage.

## Relationship to the Mavericks driver research

The modern interface-object listing should be compared with the original driver's `kStreamInterface` and `kAltInfo` tables and its explicit alternate-setting selection logic. The Mavericks static analysis records four stream-interface entries and 12 alternate-setting records, while this modern registry query shows current Audio Streaming interface objects numbered 2 through 5. This is a useful correlation to investigate, not yet proof that the legacy table entries map one-to-one to the modern objects.

The next useful hardware-side evidence is a complete raw USB configuration-descriptor capture, including every alternate setting, endpoint descriptor, packet size and class-specific audio descriptor. The next legacy-driver task is to decode all four stream-interface table entries and all 12 alternate-setting records, then trace the resulting values into interface claiming and stream setup.

## Reproduction notes

The inspection was read-only. The principal queries used included:

- `ioreg -p IOUSB -l -w 0` for the USB device object.
- `ioreg -r -c IOUSBHostInterface -l -w 0` for instantiated interface objects.
- `ioreg -r -c IOUSBHostPipe -l -w 0` for visible pipe objects.
- `ioreg -r -c AppleUSBAudioEngine -l -w 0` for a matching audio-engine object.
- `system_profiler SPAudioDataType -detailLevel full` for the system audio inventory.
- `log show --last 15m --style compact --predicate 'process == "usbaudiod"'` for recent USB-audio service messages.

The original command output was captured in the 12 November 2026 investigation conversation. Exact OS build and work-Mac model were not recorded; do not merge this observation into the M1 Pro target-system inventory as though it were collected on that machine.
