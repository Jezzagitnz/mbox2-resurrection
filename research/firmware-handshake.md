# Firmware handshake investigation

## Purpose

The original Mavericks Mbox 2 driver contains device-startup and firmware-handshake routines. Understanding this sequence is likely to be essential before a modern implementation can initialise the hardware reliably.

This document records current disassembly findings and separates confirmed instruction-level observations from interpretations and unanswered questions.

## Identified code

The following locations were identified in the inspected x86_64 Mavericks driver:

| Item | Address |
|---|---:|
| `MaudioShDrRayUsbDevice::start` | `0x4d18` |
| `MaudioShDrRayUsbDevice::RayDeviceType` | `0x4d70` |
| `MaudioShDrRayUsbDevice::initHardware` | `0x4da4` |
| `MaudioShDrRayUsbDevice::FirmwareHandshake` | `0x4fc6` |
| `MaudioShDrRayUsbDevice::performPowerStateChange` | `0x505c` |
| `MaudioShDrRayUsbDevice::performStop` | `0x506e` |
| `MaudioShDrRayUsbDevice::GetUsbDevice` | `0x50a8` |
| `MaudioShDrRayUsbDevice::UsbGetFrameNumber` | `0x50cc` |
| `MaudioShDrRayUsbDevice::UsbSetConfiguration` | `0x5118` |
| `MaudioShDrRayUsbDevice::UsbRematchInterface` | `0x51b2` |
| `MaudioShDrRayUsbDevice::UsbResetDevice` | `0x526e` |
| `MaudioShDrRayUsbDevice::UsbReEnumerateDevice` | `0x5290` |
| `HandleDigiHandshakeProperty` | `0x9f00` |
| `DigiHandshake::Do` | `0x9f66` |
| Stage 1 helper | `0xa174` |
| Stage 4 helper | `0xa1a8` |
| Stage 2 helper | `0xa1da` |
| Stage 3 helper | `0xa1e6` |

The `DigiHandshake::Do` routine compares its stage value with 4, consistent with five possible stage values (0–4). The related property handler checks a property named `LatencyProfiler`. The exact operations performed by each stage remain to be mapped.

## Device startup path: initHardware

The disassembly of `MaudioShDrRayUsbDevice::initHardware()` at `0x4da4` shows the following sequence:

1. Calls a method through the device object's vtable.
2. Reads the USB provider pointer from object offset `+0xe0`; if absent, follows an error path.
3. Calls a provider virtual method at vtable byte offset `0x8f8` and compares the returned value with `0x4000`, the Academic product ID.
4. Selects model-identification strings for the Academic, Mini, Micro or standard Mbox 2 variants. The Mini and Micro cases are selected from a further provider method result.
5. Publishes model/manufacturer-related properties through virtual calls on the device object.
6. Calls a device virtual method at offset `0xa30` with arguments `1, 0`; its result controls the subsequent path.
7. Obtains a USB-related object through provider vtable offset `0x898`, using selector/index `0` and an initial state value.
8. If that object is returned, invokes its vtable method at offset `0x20`.
9. Looks up the `bcdDevice` property on the returned object, converts it through an `OSNumber` path, and stores the resulting value at object offset `+0xf8`.
10. Calls a device virtual method at offset `0xa38` with argument `0`. Depending on its result, the code may call the same method with argument `6`, then invokes `FirmwareHandshake(false)`.
11. On the successful path following the handshake, invokes another device virtual method at offset `0xa20`.

The virtual method identities have now been resolved against the concrete RayDevice vtable, including the previously unknown +0xa30 call. The Itanium ABI vtable address point is 16 bytes after the vtable symbol. For RayDevice, the symbol is at 0x272e0 and the address point is 0x272f0. Consequently, +0xa30 targets UsbSetConfiguration(unsigned char, bool) at 0x5118; +0xa38 targets UsbRematchInterface(unsigned char) at 0x51b2; and +0xa20 targets the RayDevice::CreateAudioEngines() override at 0xc9ca. The arguments at the call sites match the method signatures: configuration (1, false), interface rematching (0) and conditionally (6), then audio-engine creation with no explicit arguments.

## FirmwareHandshake: confirmed USB request

The routine `FirmwareHandshake(bool)` at `0x4fc6` constructs a vendor-specific USB control request with these fields:

| Field | Value |
|---|---:|
| `bmRequestType` | `0xC0` |
| `bRequest` | `0x85` |
| `wValue` | Boolean argument + 1 |
| `wIndex` | `0x0001` |
| `wLength` | `1` |
| Response length | 1 byte |

The request is submitted through the USB provider's virtual method at vtable byte offset `0x938`. The response byte is initialised to zero before the request.

If the transfer succeeds and the response byte equals `1`, the routine sleeps for 300 ms and retries. The loop allows up to 30 retries after the initial request. A transfer error or a response other than `1` exits the polling loop.

This establishes the request fields and polling behaviour of this particular Mavericks driver routine. It does not, by itself, establish the semantic meaning of every response value or prove that this is the only firmware-readiness protocol used by the device.

## USB lifecycle helper methods

The device class contains several USB lifecycle wrappers:

### UsbSetConfiguration

At `0x5118`, this method checks the provider pointer and then coordinates several provider virtual calls:

- `+0x5d0` as a preparation step;
- `+0x8c0` with the requested configuration byte and Boolean argument;
- `+0x5e0` to inspect a subsequent state;
- conditionally `+0x5d8` with argument zero.

It returns operation status and has explicit error paths. This is a coordinated operation, not yet proven to be a direct one-to-one wrapper around a single USB API call.

### UsbRematchInterface

At `0x51b2`, this method obtains an iterator-like object through provider vtable offset `+0x898`, walks returned objects using their vtable method at `+0x20`, obtains an interface number through provider vtable offset `+0x8b0`, and compares it with the requested interface number. On a match it invokes another virtual method at offset `+0x5b0` with argument `2`. It releases objects through vtable offset `+0x28` and continues iteration.

This is consistent with interface lookup/rematching behaviour, but the exact provider and interface method identities remain unconfirmed.

### UsbResetDevice and UsbReEnumerateDevice

- `UsbResetDevice` at `0x526e` calls provider vtable offset `+0x8b8`.
- `UsbReEnumerateDevice` at `0x5290` calls provider vtable offset `+0x990` with argument zero.

The exact underlying IOKit method names and the circumstances in which these helpers are called remain to be identified.

## Vtable investigation status

The symbol table places the MaudioShDrRayUsbDevice vtable at 0x20ee0; its Itanium ABI address point is 0x20ef0. Its +0xa20 slot resolves to the base stub CreateAudioEngines() at 0x547a (which simply returns 0xe00002bc); its +0xa30 slot resolves to UsbSetConfiguration() at 0x5118; and its +0xa38 slot resolves to UsbRematchInterface() at 0x51b2.

The concrete RayDevice vtable symbol is at 0x272e0, with address point 0x272f0. Its +0xa20 slot points to RayDevice::CreateAudioEngines() at 0xc9ca, overriding the base stub. Its +0xa30 and +0xa38 slots point to UsbSetConfiguration() at 0x5118 and UsbRematchInterface() at 0x51b2, respectively. The address-point adjustment is essential: indexing from the vtable symbol itself would misassign the slots.

## Comparison with Linux boot quirk

The Linux Mbox 2 boot quirk uses the same request type and request code (`0xC0 / 0x85`) but a different request shape:

| Field | Linux boot quirk |
|---|---:|
| `bmRequestType` | `0xC0` |
| `bRequest` | `0x85` |
| `wValue` | `0x0001` |
| `wIndex` | `0x0000` |
| `wLength` | `0x0012` (18 bytes) |
| Poll interval | 500 ms |
| Maximum attempts | 10 |
| Response byte 0 | `0x02` ready; `0x01` loading |

The Linux path also checks that the configuration descriptor total length is 646 bytes before applying the boot quirk. It then rereads the device descriptor, resets USB configuration and performs additional 48 kHz / 24-bit setup requests.

**Do not conflate the Linux 18-byte boot-status exchange with the Mavericks driver's one-byte `FirmwareHandshake` request.** The common request type and code are notable, but their indices, lengths, response formats and polling behaviour differ.

## Current interpretation

The Mavericks driver has a device startup path that identifies the product variant, obtains a USB-related object, reads the device revision, invokes additional virtual methods and performs a one-byte firmware-related control request with retry behaviour. A separate multi-stage `DigiHandshake::Do` path also exists.

The relationship between these two handshake mechanisms, and the exact meaning of each operation, is not yet fully established.

## Important unanswered questions

- What are the concrete method identities behind the provider vtable offsets used above?
- Which startup branches call reset or re-enumeration, and what are the concrete provider/interface methods behind those helper calls?
- What does the one-byte response value `1` represent in the Mavericks routine?
- How does the Mavericks request relate to the Linux 18-byte boot-status protocol?
- What USB operations occur in each of the five `DigiHandshake::Do` stages?
- At what point is the device ready for audio-engine creation and streaming?
- Are the same sequences used for every Mbox 2 hardware and firmware revision?

The legacy utility's green “locked” indicator must not currently be described as proof of S/PDIF clock lock. Its exact meaning remains an open question.

## Next steps

1. Resolve the provider and interface vtable methods used inside UsbSetConfiguration() and UsbRematchInterface().
2. Trace callers of UsbResetDevice() and UsbReEnumerateDevice() and determine whether either participates in startup.
3. Examine each DigiHandshake::Do stage helper and its callers, keeping it distinct from the USB firmware request.
4. Map the resulting operations to runtime behaviour on the known-working Mavericks reference system.
5. Record the exact binary version and hash alongside any conclusions.


## 6 November 2026 update — resolved device vtable calls

The `RayDevice` vtable dump and symbol table establish the concrete targets of two calls made by `initHardware()`:

| Virtual slot | `RayDevice` target | Meaning |
|---|---:|---|
| `+0xa38` | `0x51b2` | `UsbRematchInterface(unsigned char)` |
| `+0xa20` | `0xc9ca` | `RayDevice::CreateAudioEngines()` |

The Itanium ABI address point is 16 bytes after the vtable symbol. `RayDevice`'s vtable symbol is `0x272e0`, address point `0x272f0`; the two slots are therefore at `0x27d28` and `0x27d10`, respectively. The base class has a stub `CreateAudioEngines()` at `0x547a`, but the derived `RayDevice` overrides it at `0xc9ca`.

This confirms that `initHardware()` attempts to rematch USB interface numbers 0 and 6 through the same virtual method, performs `FirmwareHandshake(false)` on the relevant path, and calls the concrete audio-engine creation override after successful setup. At the time of this historical 6 November note, the `+0xa30` operation had not yet been identified. The 25 November update below resolves it as `UsbSetConfiguration(1, false)`. Static disassembly does not prove the runtime outcome of either rematch.


## 25 November 2026 update — complete initHardware vtable resolution

A fresh read-only disassembly of initHardware() (0x4da4 through 0x4fc5), the symbol table, and raw vtable entries on the Mavericks reference system resolved all three relevant virtual calls.

### Correct slot mapping

The Itanium C++ ABI vtable address point is 16 bytes after the vtable symbol. For RayDevice, the symbol is 0x272e0 and the address point is 0x272f0. The raw 64-bit entries were read around 0x27d00; the relevant function pointers are:

| Virtual byte offset from address point | Vtable entry address | Function pointer | Resolved method |
|---|---:|---:|---|
| +0xa20 | 0x27d10 | 0xc9ca | RayDevice::CreateAudioEngines() |
| +0xa28 | 0x27d18 | 0x506e | MaudioShDrRayUsbDevice::performStop() |
| +0xa30 | 0x27d20 | 0x5118 | MaudioShDrRayUsbDevice::UsbSetConfiguration(unsigned char, bool) |
| +0xa38 | 0x27d28 | 0x51b2 | MaudioShDrRayUsbDevice::UsbRematchInterface(unsigned char) |

The base-class vtable at symbol 0x20ee0 has address point 0x20ef0. Its +0xa20 entry points to 0x547a, the base CreateAudioEngines() stub, which simply returns 0xe00002bc. RayDevice overrides this slot with the real implementation at 0xc9ca.

**Correction to the earlier working interpretation:** the +0xa30 call is not audio-engine creation. The previous raw-table reading treated the vtable symbol as the address point and missed the ABI's 16-byte prefix. With the address point applied, +0xa30 is UsbSetConfiguration(1, false). Audio-engine creation is the later +0xa20 call.

### Startup control flow established by the disassembly

1. After model identification and property publication, initHardware() calls UsbSetConfiguration(1, false).
2. The return value is checked. A non-zero result takes an error return path after calling FirmwareHandshake(false); a zero result continues.
3. The driver obtains the USB-related object, reads its bcdDevice property, and calls UsbRematchInterface(0).
4. If that call returns zero, it next calls UsbRematchInterface(6).
5. It then calls FirmwareHandshake(false).
6. If the second rematch returned zero, the driver invokes RayDevice::CreateAudioEngines() at 0xc9ca.
7. The function's return status is based on the relevant operation's return value; static disassembly does not prove that every branch succeeds on every device/firmware revision.

The disassembly therefore establishes the intended ordering of configuration, interface rematching, firmware polling, and audio-engine creation. It does not establish that the Mavericks and Linux vendor requests are consecutive stages, nor does it prove the runtime result of any step on the modern macOS implementation.

### Evidence and safety boundary

- The inspected original driver on the Mac mini was 434,424 bytes, dated 4 October 2014, SHA-256:
  7dd2fb0d19b80aa3615aa72866c00a98345fbc6e3e375e70d9cbca6411539f9d.
- This was static inspection of the existing binary and its symbol/vtable data.
- No Mbox vendor control request, configuration change, interface rematch, reset, re-enumeration, or endpoint transfer was sent by this investigation.
- No security settings or system services were changed.

### Next investigation

Inspect the implementation of UsbSetConfiguration() at 0x5118 and resolve the provider virtual calls it makes. Then trace the concrete provider methods and establish exactly what configuration value 1 and Boolean false cause the original driver to request. Continue to treat all hardware operations as unauthorised until each proposed request is described and explicitly approved by the user.
