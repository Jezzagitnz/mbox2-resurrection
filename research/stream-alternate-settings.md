# Mbox 2 stream-interface and alternate-setting selection

**Date:** 7 November 2026  
**Reference system:** OS X Mavericks 10.9.5, build 13F1911  
**Binary:** `/System/Library/Extensions/DigidesignMbox2.kext/Contents/MacOS/DigidesignMbox2`  
**Driver:** `com.digidesign.mbox2.driver` 10.3.9f4 (short version 10.3.9.12), x86_64  
**Related component:** DigiDal 10.3.10d4  
**Evidence type:** Symbol and static disassembly analysis; runtime behaviour not established.

## Scope

This note records the first identified logic that selects a USB audio alternate setting in the Mavericks Mbox 2 driver. It extends the existing device/USB lifecycle map without assuming that alternate-setting numbers identify particular sample rates, bit depths, or clock sources.

## Confirmed observations

### Alternate-setting selection

`RayEngine::GetAlternateSetting` is located at `0xc2d0`. The routine calls `RayPrefData::GetClockSource()` at `0xb332` and selects an alternate-setting number using the AC-3 state and the returned clock-source byte:

| Condition observed in the routine | Selected alternate setting |
|---|---:|
| AC-3 enabled | `6` |
| AC-3 not enabled, clock-source byte equals `1` | `2` |
| AC-3 not enabled, clock-source byte is any other value | `3` |

The routine's supplied sample-rate and audio-format arguments are not inspected by this selection logic. This is a statement about this function's control flow only; it does not establish that sample rate or format are ignored by later engine or USB setup code.

### Stream-interface and alternate-setting tables

The symbol locations and counts recorded for the `__TEXT,__const` data are:

| Symbol | Address | Recorded value / meaning |
|---|---:|---|
| `kStreamInterface` | `0x1dab0` | Start of stream-interface table |
| `kStreamInterfaceCount` | `0x1dae0` | Count: 4 entries |
| `kAltInfo` | `0x1db30` | Start of alternate-setting information table |
| `kAltInfoCount` | `0x1dc80` | Count: 12 records |

The alternate-setting table contains 12 records of 28 bytes each (`0x1c` bytes). The lookup routine identified as `GetAlternateSettingInfo` compares the first byte of a record with the requested interface ID and the second byte with the requested alternate-setting number. When both match, it copies the corresponding record for subsequent use.

The inspected `__TEXT,__const` section was recorded at `0x11e60`, size `0xbed0`. That extent is consistent with the table symbols near `0x1dab0`–`0x1dc80`.

The full field layout and all 12 record contents have not yet been decoded. The count and record size do not by themselves reveal which audio format or endpoint configuration each record represents.

## Interpretation — provisional

- The driver has a table-driven description of per-interface alternate settings, and a separate selection function chooses setting 2, 3, or 6 based on AC-3 state and the clock-source byte.
- Because the sample-rate and audio-format arguments are not read in `RayEngine::GetAlternateSetting`, this particular decision appears to be driven by those two state inputs rather than by direct comparison of the requested rate or format.
- The clock-source byte value `1` must remain an opaque value at this stage. It has not been established as internal clock, external clock, S/PDIF, or any other named mode.

These interpretations describe the static code path; they do not establish what the hardware reports or successfully streams at runtime.

## Unresolved questions

1. What are the meanings and complete field offsets of the 28-byte alternate-setting records?
2. What are the actual interface IDs and alternate-setting numbers in all 12 records?
3. Which of the four stream-interface entries correspond to the USB interfaces selected during device initialisation?
4. What does clock-source byte value `1` represent, and what are the other possible values?
5. What does the AC-3 state represent: a user preference, a device capability, a transport mode, or another condition?
6. Why does AC-3 select alternate setting `6`, and how does that setting differ from `2` and `3` at the endpoint/format level?
7. Where are sample rate and bit depth applied after this alternate-setting decision?
8. Does the same selection logic apply across all Mbox 2 hardware and firmware revisions?

## Evidence limits and next steps

These findings come from static symbol/disassembly analysis of the Mavericks x86_64 driver. They do not prove that a selected alternate setting is accepted by the device, that the corresponding endpoint is active, or that audio streaming works. The retained research record preserves the decoded branch behaviour and symbol locations, but not the complete raw disassembly transcript or all table bytes; those should be captured before attempting a full record-by-record interpretation.

Next, dump the complete `kStreamInterface` and `kAltInfo` data ranges with addresses, decode every 28-byte record, and trace each copied field to the code that opens/configures the USB interface and advertises stream formats. Keep clock-source values and AC-3 state as raw inputs until their setters, callers, and user-visible controls are identified.

See also [Original driver architecture](driver-architecture.md), [Mavericks driver research](mavericks-driver.md), and [Mbox 2 USB interface lifecycle research](usb-interface-lifecycle.md).


## 11 November 2026 update — interface enablement and preference bytes

Further disassembly identifies `RayPrefData::IsInterfaceEnabled(unsigned char)` at `0xb2f2`. The method calls a boolean virtual predicate through the `RayPrefData` vtable slot at byte offset `0x48`, then applies this interface-ID rule:

| Result of vtable predicate | Interface IDs accepted by `IsInterfaceEnabled()` |
|---|---|
| True | Only interface ID `3` |
| False | IDs `2`, `4` and `5` (bit mask `0x34`, with IDs above `5` rejected) |

This is a confirmed rule in the helper's control flow. The complete four-entry `kStreamInterface` table has not yet been decoded in the saved evidence, so the table's exact contents should not be inferred from this predicate alone.

Two named preference helpers expose adjacent bytes in the preference-data object:

- `RayPrefData::GetClockSource()` at `0xb332` reads byte `0` from the preference-data pointer stored at `RayPrefData + 0x10`.
- `RayPrefData::IsOutputAc3()` at `0xb370` reads byte `1` from that same pointer and returns whether it is nonzero.

This confirms that the first two preference bytes are read separately as the clock-source value and an output-AC-3 flag by these named helpers. It does not establish the complete structure size or all possible values.

**Important vtable qualification:** `RayEngine::GetAlternateSetting()` at `0xc2d0` and `RayPrefData::IsInterfaceEnabled()` at `0xb2f2` both call vtable slot `+0x48`. The 11 November captures identify the named `IsOutputAc3()` helper and its byte read, but do not include the relocation that proves slot `+0x48` resolves to that helper. The earlier AC-3 interpretation of the true branch therefore remains a working interpretation until the `RayPrefData` vtable entry is mapped.

The new [asynchronous input transport and sample-buffer research](async-input-audio-path.md) records the separate low-latency input-frame queue and sample-rate tracking path. These static findings do not establish that any alternate setting is accepted at runtime or that the corresponding interface streams audio.
